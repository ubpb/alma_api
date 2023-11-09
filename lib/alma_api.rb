require "active_support"
require "active_support/core_ext"
require "faraday"
require "nokogiri"
require "hashie"
require "oj"

require "alma_api/configuration"
require "alma_api/client"

module AlmaApi
  DEFAULT_ERROR_CODE = "UNKNOWN".freeze
  DEFAULT_ERROR_MESSAGE = "Unknown cause".freeze

  class Error < StandardError
    attr_reader :code

    def initialize(message, code)
      @code = code.presence || DEFAULT_ERROR_CODE
      super(message.presence || DEFAULT_ERROR_MESSAGE)
    end
  end

  class GatewayError < Error; end
  class ServerError  < Error; end
  class LogicalError < Error; end

  GATEWAY_ERROR_CODES = [
    "GENERAL_ERROR",
    "UNAUTHORIZED",
    "INVALID_REQUEST",
    "PER_SECOND_THRESHOLD",
    "DAILY_THRESHOLD",
    "REQUEST_TOO_LARGE",
    "FORBIDDEN",
    "ROUTING_ERROR"
  ].freeze

  class << self

    def configure
      configuration = Configuration.new
      yield(configuration) if block_given?
      Client.new(configuration)
    end

    def validate_format!(format)
      case format = format&.to_s
      when "json", "xml" then format
      when nil then nil
      else
        raise ArgumentError, "Unsupported format '#{format}'. Only 'json' and 'xml' is supported."
      end
    end

  end
end
