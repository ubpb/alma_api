require "test_helper"

module AlmaApi
  class ClientTest < Minitest::Test

    def setup
      @client = AlmaApi.configure do |config|
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
        body:   %(
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <web_service_result xmlns="http://com/exlibris/urm/general/xmlbeans">
            <errorsExist>true</errorsExist>
            <errorList>
              <error>
                <errorCode>GENERAL_ERROR</errorCode>
                <errorMessage>Some Error Message</errorMessage>
              </error>
            </errorList>
          </web_service_result>
        )
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

      expected = {error_message: "Logical error", error_code: "LOGICAL_ERROR"}

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

      expected = {error_message: "Logical error", error_code: "LOGICAL_ERROR"}

      assert_equal expected, @client.send(:parse_error_response_body, json)
    end

    def test_parse_error_response_body_with_unsupported_content_type
      assert_equal({error_message: nil, error_code: nil}, @client.send(:parse_error_response_body, "unsupported"))
    end

    def test_handle_faraday_error_with_missing_response
      assert_raises(AlmaApi::ServerError) {
        assert_equal(true, @client.send(:handle_faraday_error, Faraday::Error.new))
      }
    end

    def test_is_xml_response
      assert_equal(true, @client.send(:is_xml_response?, "<foo>bar</foo>"))
    end

    def test_is_json_response
      assert_equal(true, @client.send(:is_json_response?, '{"foo":"bar"}'))
    end

  end
end
