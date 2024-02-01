module AlmaApi
  class Client

    attr_reader :configuration,
                :remaining_api_calls

    def initialize(configuration)
      @configuration = configuration
      @remaining_api_calls = -1
    end

    def get(url, params: {}, format: nil)
      perform_request do
        connection(format: format, params: params).get(url)
      end
    end

    def post(url, params: {}, body: nil, format: nil)
      perform_request do
        connection(format: format, params: params).post(url) do |req|
          req.body = body
        end
      end
    end

    def put(url, params: {}, body: nil, format: nil)
      perform_request do
        connection(format: format, params: params).put(url) do |req|
          req.body = body
        end
      end
    end

    def delete(url, params: {}, format: nil)
      perform_request do
        connection(format: format, params: params).delete(url)
      end
    end

  private

    def connection(format: nil, params: {})
      # The format parameter is used to specify the format of the request.
      # Alma supports both JSON and XML, but the default is JSON.
      format = case AlmaApi.validate_format!(format)
               when "xml"  then "application/xml"
               when "json" then "application/json"
               else
                 "application/json"
               end

      # Setup default parameters. For now just the language.
      # If the language is not specified, then the default language is English.
      default_params = {
        lang: configuration.language
      }.reject do |k, v|
        k == :lang && (v.blank? || v == "en")
      end

      # Finally create and return the Faraday connection object.
      Faraday.new(
        configuration.base_url,
        params:  default_params.reverse_merge(params),
        headers: {
          "Authorization": "apikey #{configuration.api_key}",
          "Accept":        format,
          "Content-Type":  format
        }
      ) do |faraday|
        faraday.response :raise_error # raise Faraday::Error on status code 4xx or 5xx
      end
    end

    def perform_request
      response = yield
      set_remaining_api_calls(response)
      parse_response_body(response.body)
    rescue Faraday::Error => e
      handle_faraday_error(e)
    rescue StandardError
      raise Error, UNEXPECTED_ERROR_MESSAGE
    end

    def handle_faraday_error(error)
      raise Error, UNEXPECTED_ERROR_MESSAGE if error.response_body.blank?

      # The error response body is either XML, JSON or empty, so we need to parse it
      error_response = parse_error_response_body(error.response_body)

      # Throw our own error based on the error code from the response and/or the
      # response status.
      case error_response[:error_code]
      when *GATEWAY_ERROR_CODES
        raise GatewayError.new(error_response[:error_message], error_response[:error_code])
      else
        case error.response_status
        when 400..499
          raise LogicalError.new(error_response[:error_message], error_response[:error_code])
        when 500..599
          raise ServerError.new(error_response[:error_message], error_response[:error_code])
        else
          raise Error, UNEXPECTED_ERROR_MESSAGE
        end
      end
    end

    def set_remaining_api_calls(response)
      rac = response.headers[:x_alma_api_remaining]
      @remaining_api_calls = rac.to_i if rac.present?
    end

    def parse_response_body(body)
      if body.blank?
        nil
      elsif is_xml_response?(body)
        Nokogiri::XML.parse(body)
      elsif is_json_response?(body)
        Oj.load(body)
      else
        raise Error.new("Unsupported content type in response from API.", "API_CLIENT_ERROR")
      end
    end

    def parse_error_response_body(body)
      if is_xml_response?(body)
        xml = Nokogiri::XML.parse(body)
        error_message = xml.at("errorMessage")&.text
        error_code    = xml.at("errorCode")&.text

        {error_message: error_message, error_code: error_code}
      elsif is_json_response?(body)
        json = Oj.load(body)
        json.extend Hashie::Extensions::DeepFind

        # Sometimes the format is:
        #   {"errorList":{"error":[{"errorCode":"xxx","errorMessage":"xxx"}]}}
        # and sometimes the format is:
        #   {"web_service_result":{"errorList":{"error":{"errorMessage":"xxx","errorCode":"xxx"}}}}
        # so we use a deep find to find the first occurrence of "errorMessage" and "errorCode"
        error_message = json.deep_find("errorMessage")
        error_code    = json.deep_find("errorCode")

        {error_message: error_message, error_code: error_code}
      else
        {error_message: nil, error_code: nil}
      end
    end

    def is_xml_response?(body)
      body&.strip&.starts_with?("<")
    end

    def is_json_response?(body)
      body&.strip&.starts_with?("{")
    end

  end
end
