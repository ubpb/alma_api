module AlmaApi
  class Client
    class << self
      def configure
        configuration = Configuration.new
        yield(configuration) if block_given?
        new(configuration)
      end
    end

    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
      @remaining_api_calls = -1
    end

    def get(url, params: {}, format: nil)
      perform_request do
        connection(format: format, params: params).get(url) do |req|
          yield(req) if block_given?
        end
      end
    end

    def post(url, params: {}, body: nil, format: nil)
      perform_request do
        connection(format: format, params: params).post(url) do |req|
          req.body = body
          yield(req) if block_given?
        end
      end
    end

    def put(url, params: {}, body: nil, format: nil)
      perform_request do
        connection(format: format, params: params).put(url) do |req|
          req.body = body
          yield(req) if block_given?
        end
      end
    end

    def delete(url, params: {}, format: nil)
      perform_request do
        connection(format: format, params: params).delete(url) do |req|
          yield(req) if block_given?
        end
      end
    end

    def remaining_api_calls
      response = connection.get("users/operation/test")
      rac = response.headers["x-exl-api-remaining"]
      rac.present? ? rac.to_i : -1
    rescue StandardError
      -1
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

      # Merge the default parameters with the parameters passed in.
      params = default_params.reverse_merge(params)

      # Setup the headers for the request.
      headers = {
        "Authorization" => "apikey #{configuration.api_key}",
        "Accept"        => format,
        "Content-Type"  => format
      }

      # If the params contains a password parameter, delete that from the params
      # and add it to the headers. This is a special case for the Alma API when
      # authenticating a user.
      # @see https://developers.exlibrisgroup.com/alma/apis/docs/users/UE9TVCAvYWxtYXdzL3YxL3VzZXJzL3t1c2VyX2lkfQ==/
      if (password = params.delete(:password) || params.delete("password")).present?
        headers["Exl-User-Pw"] = password
      end

      # Finally create and return the Faraday connection object.
      Faraday.new(
        configuration.base_url,
        request: {
          timeout: configuration.timeout
        },
        params:  params,
        headers: headers
      ) do |faraday|
        faraday.response :raise_error # raise Faraday::Error on status code 4xx or 5xx
      end
    end

    def perform_request
      response = yield
      parse_response_body(response.body)
    rescue Faraday::Error => e
      handle_faraday_error(e)
    rescue StandardError
      raise Error, GENERAL_ERROR_MESSAGE
    end

    def handle_faraday_error(error)
      # The error response body is either XML, JSON or empty, so we need to parse it
      error_message, error_code = parse_error_response_body(error.response_body)

      if error_message.present? && error_code.present?
        # Raise a gateway error if the error code is one of the gateway error codes
        raise GatewayError.new(error_message, error_code) if GATEWAY_ERROR_CODES.include?(error_code)

        # Check the response status code
        case error.response_status
        when 400..499
          raise LogicalError.new(error_message, error_code)
        when 500..599
          raise ServerError.new(error_message, error_code)
        end
      end

      # If we get here, then we don't know what the error is, so we raise a generic error.
      raise Error, GENERAL_ERROR_MESSAGE
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
      error_message = nil
      error_code = nil

      if is_xml_response?(body)
        xml = Nokogiri::XML.parse(body)
        error_message = xml.at("errorMessage")&.text&.presence
        error_code    = xml.at("errorCode")&.text&.presence&.upcase
      elsif is_json_response?(body)
        json = Oj.load(body)
        json.extend Hashie::Extensions::DeepFind

        # Sometimes the format is:
        #   {"errorList":{"error":[{"errorCode":"xxx","errorMessage":"xxx"}]}}
        # and sometimes the format is:
        #   {"web_service_result":{"errorList":{"error":{"errorMessage":"xxx","errorCode":"xxx"}}}}
        # so we use a deep find to find the first occurrence of "errorMessage" and "errorCode"
        error_message = json.deep_find("errorMessage")&.presence
        error_code    = json.deep_find("errorCode")&.presence
      end

      [error_message, error_code]
    end

    def is_xml_response?(body)
      body&.strip&.starts_with?("<")
    end

    def is_json_response?(body)
      body&.strip&.starts_with?("{")
    end

  end
end
