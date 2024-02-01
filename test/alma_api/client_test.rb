require "test_helper"

module AlmaApi
  class ClientTest < Minitest::Test

    def setup
      @client = AlmaApi::Client.configure do |config|
        config.api_key = "1234"
        config.base_url = "https://api-eu.hosted.exlibrisgroup.com"
        config.default_format = "json"
      end

      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/foo/bar"
      ).with(
        headers: {
          "Accept" => "application/json"
        }
      ).to_return(
        status: 200,
        body: '{"foo": "bar"}'
      )

      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/foo/bar"
      ).with(
        headers: {
          "Accept" => "application/xml"
        }
      ).to_return(
        status: 200,
        body: '<?xml version="1.0" encoding="UTF-8"?><foo><bar>baz</bar></foo>'
      )
    end

    def gateway_error_response
      generic_error_response("GENERAL_ERROR", "Some Error Message")
    end

    def generic_error_response(error_code="42", error_message="Some Error Message")
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <web_service_result xmlns="http://com/exlibris/urm/general/xmlbeans">
          <errorsExist>true</errorsExist>
          <errorList>
            <error>
              <errorCode>#{error_code}</errorCode>
              <errorMessage>#{error_message}</errorMessage>
            </error>
          </errorList>
        </web_service_result>
      XML
    end

    def test_get_json
      response = @client.get("/foo/bar", format: "json")

      assert_equal({"foo" => "bar"}, response)
    end

    def test_get_xml
      response = @client.get("/foo/bar", format: "xml")

      assert_equal(response.class, Nokogiri::XML::Document)
      assert_equal("baz", response.xpath("//bar").text)
    end

    def test_post_json
      response = @client.post("/foo/bar", body: '{some: "json"}')

      assert_equal({"foo" => "bar"}, response)
    end

    def test_post_xml
      response = @client.post("/foo/bar", body: '<some>xml</some>', format: "xml")

      assert_equal(response.class, Nokogiri::XML::Document)
      assert_equal("baz", response.xpath("//bar").text)
    end

    def test_put_json
      response = @client.put("/foo/bar", body: '{some: "json"}')

      assert_equal({"foo" => "bar"}, response)
    end

    def test_put_xml
      response = @client.put("/foo/bar", body: '<some>xml</some>', format: "xml")

      assert_equal(response.class, Nokogiri::XML::Document)
      assert_equal("baz", response.xpath("//bar").text)
    end

    def test_delete_json
      response = @client.delete("/foo/bar")

      assert_equal({"foo" => "bar"}, response)
    end

    def test_delete_xml
      response = @client.delete("/foo/bar", format: "xml")

      assert_equal(response.class, Nokogiri::XML::Document)
      assert_equal("baz", response.xpath("//bar").text)
    end

    def test_perform_request_with_gateway_error
      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/gateway_error"
      ).to_return(
        status: 500,
        body: gateway_error_response
      )

      assert_raises(AlmaApi::GatewayError) { @client.get("/gateway_error") }
      assert_raises(AlmaApi::GatewayError) { @client.get("/gateway_error", format: :xml) }
    end

    def test_perform_request_with_server_error
      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/server_error"
      ).to_return(
        status: 500,
        body:   %(
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <web_service_result xmlns="http://com/exlibris/urm/general/xmlbeans">
            <errorsExist>true</errorsExist>
            <errorList>
              <error>
                <errorCode>42</errorCode>
                <errorMessage>Some Error Message</errorMessage>
              </error>
            </errorList>
          </web_service_result>
        )
      )

      assert_raises(AlmaApi::ServerError) { @client.get("/server_error") }
      assert_raises(AlmaApi::ServerError) { @client.get("/server_error", format: :xml) }
    end

    def test_perform_request_with_logical_error
      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/logical_error"
      ).to_return(
        status: 400,
        body:   %(
          {
            "errorsExist": true,
            "errorList": {
              "error": [
                {
                  "errorCode": "401861",
                  "errorMessage": "User with identifier 1234 was not found."
                }
              ]
            }
          }
        )
      )

      assert_raises(AlmaApi::LogicalError) { @client.get("/logical_error") }
    end

    def test_perform_request_with_general_error
      assert_raises(AlmaApi::Error) {
        @client.send(:perform_request) do
          raise ArgumentError, "Some error"
        end
      }
    end

    def test_handle_faraday_error
      error = Faraday::Error.new

      # Error without response body must raise a generic error
      error.stub(:response_body, "") do
        assert_raises(AlmaApi::Error) {
          @client.send(:handle_faraday_error, error)
        }
      end

      # Error with response body that has no message and code must raise a generic error
      error.stub(:response_body, "Foo bar error") do
        assert_raises(AlmaApi::Error) {
          @client.send(:handle_faraday_error, error)
        }
      end

      # Error with an Alma response body and 4xx status code must raise a logical error
      error.stub(:response_body, generic_error_response) do
        error.stub(:response_status, 400) do
          assert_raises(AlmaApi::LogicalError) {
            @client.send(:handle_faraday_error, error)
          }
        end
      end

      # Error with an Alma response body and 5xx status code must raise a server error
      error.stub(:response_body, generic_error_response) do
        error.stub(:response_status, 500) do
          assert_raises(AlmaApi::ServerError) {
            @client.send(:handle_faraday_error, error)
          }
        end
      end

      # Error with an Gateway response body and 5xx status code must raise a gateway error
      error.stub(:response_body, gateway_error_response) do
        error.stub(:response_status, 500) do
          assert_raises(AlmaApi::GatewayError) {
            @client.send(:handle_faraday_error, error)
          }
        end
      end
    end

    def test_parse_response_body_with_xml
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <foo>
          <bar>baz</bar>
        </foo>
      XML

      result = @client.send(:parse_response_body, xml)

      assert_equal(result.class, Nokogiri::XML::Document)
      assert_equal("baz", result.xpath("//bar").text)
    end

    def test_parse_response_body_with_json
      json = '{"foo":"bar"}'

      result = @client.send(:parse_response_body, json)

      assert_equal({"foo" => "bar"}, result)
    end

    def test_parse_response_body_with_unsupported_content_type
      assert_raises(AlmaApi::Error) {
        @client.send(:parse_response_body, "unsupported")
      }
    end

    def test_parse_error_response_body_with_xml
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <web_service_result>
          <errorList>
            <error>
              <errorCode>LOGICAL_ERROR</errorCode>
              <errorMessage>Logical error</errorMessage>
            </error>
          </errorList>
        </web_service_result>
      XML

      expected = ["Logical error", "LOGICAL_ERROR"]

      assert_equal expected, @client.send(:parse_error_response_body, xml)
    end

    def test_parse_error_response_body_with_json
      json = <<~JSON
        {
          "web_service_result": {
            "errorList": {
              "error": {
                "errorMessage": "Logical error",
                "errorCode": "LOGICAL_ERROR"
              }
            }
          }
        }
      JSON

      expected = ["Logical error", "LOGICAL_ERROR"]

      assert_equal expected, @client.send(:parse_error_response_body, json)
    end

    def test_parse_error_response_body_with_unsupported_content_type
      assert_equal([nil, nil], @client.send(:parse_error_response_body, "unsupported"))
    end

    def test_is_xml_response
      assert_equal(true, @client.send(:is_xml_response?, "<foo>bar</foo>"))
      assert_equal(true, @client.send(:is_xml_response?, "  <foo>bar</foo>  "))
      assert_equal(false, @client.send(:is_xml_response?, " "))
      assert_equal(false, @client.send(:is_xml_response?, "{"))
    end

    def test_is_json_response
      assert_equal(true, @client.send(:is_json_response?, '{"foo":"bar"}'))
      assert_equal(true, @client.send(:is_json_response?, '  {"foo":"bar"}  '))
      assert_equal(false, @client.send(:is_json_response?, " "))
      assert_equal(false, @client.send(:is_json_response?, "<"))
    end

    def test_password_param_goes_into_header
      connection = @client.send(:connection, params: {password: "secret"})
      assert_equal("secret", connection.headers["Exl-User-Pw"])
      assert_nil(connection.params[:password])
    end

    def test_remaining_api_calls
      stub_request(
        :any,
        "https://api-eu.hosted.exlibrisgroup.com/users/operation/test"
      ).to_return(
        status:  200,
        headers: {"x-exl-api-remaining": "42"}
      )

      assert_equal(42, @client.remaining_api_calls)

      # Force a StandardError to be raised
      @client.stub(:connection, nil) do
        assert_equal(-1, @client.remaining_api_calls)
      end
    end

  end
end
