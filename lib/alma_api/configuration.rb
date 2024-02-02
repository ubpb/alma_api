module AlmaApi
  class Configuration

    GATEWAYS = {
      na: "https://api-na.hosted.exlibrisgroup.com/almaws/v1", # North America
      eu: "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", # Europe
      ap: "https://api-ap.hosted.exlibrisgroup.com/almaws/v1", # Asia-Pacific
      ca: "https://api-ca.hosted.exlibrisgroup.com/almaws/v1", # Canada
      cn: "https://api-cn.hosted.exlibrisgroup.cn/almaws/v1"   # China
    }.freeze

    DEFAULT_GATEWAY  = GATEWAYS[:eu].freeze
    DEFAULT_FORMAT   = "json".freeze
    DEFAULT_LANGUAGE = "en".freeze

    attr_reader :api_key,
                :base_url,
                :default_format,
                :language,
                :timeout

    def initialize(api_key: nil)
      # Set defaults. Passing nil to the setters will set the default value.
      self.api_key = api_key
      self.base_url = nil
      self.default_format = nil
      self.language = nil
      self.timeout = nil

      # Yield self to allow block-style configuration.
      yield(self) if block_given?
    end

    def api_key=(value)
      @api_key = value.presence
    end

    def base_url=(value)
      if value.is_a?(Symbol)
        raise ArgumentError, "Invalid gateway: #{value}" unless GATEWAYS.keys.include?(value)

        @base_url = GATEWAYS[value]
      elsif value.is_a?(String)
        @base_url = value.presence || DEFAULT_GATEWAY
      else
        @base_url = DEFAULT_GATEWAY
      end
    end

    def default_format=(value)
      @default_format = AlmaApi.validate_format!(value) || DEFAULT_FORMAT
    end

    def language=(value)
      @language = value.presence&.to_s || DEFAULT_LANGUAGE
    end

    def timeout=(value)
      @timeout = value.presence
    end

  end
end
