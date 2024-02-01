module AlmaApi
  class Configuration

    GATEWAYS = {
      na: "https://api-na.hosted.exlibrisgroup.com/almaws/v1", # North America
      eu: "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", # Europe
      ap: "https://api-ap.hosted.exlibrisgroup.com/almaws/v1", # Asia-Pacific
      ca: "https://api-ca.hosted.exlibrisgroup.com/almaws/v1", # Canada
      cn: "https://api-cn.hosted.exlibrisgroup.cn/almaws/v1"   # China
    }.freeze

    DEFAULT_FORMAT   = "json".freeze
    DEFAULT_LANGUAGE = "en".freeze

    attr_reader :api_key,
                :base_url,
                :default_format,
                :language

    def initialize(api_key: nil, base_url: nil, default_format: nil, language: nil)
      self.api_key = api_key
      self.base_url = base_url
      self.default_format = default_format
      self.language = language
    end

    def api_key=(value)
      @api_key = value.presence
    end

    def base_url=(value)
      if value.is_a?(Symbol)
        raise ArgumentError, "Invalid gateway: #{value}" unless GATEWAYS.keys.include?(value)

        @base_url = GATEWAYS[value]
      else
        @base_url = value.presence || GATEWAYS[:eu]
      end
    end

    def default_format=(value)
      @default_format = AlmaApi.validate_format!(value) || DEFAULT_FORMAT
    end

    def language=(value)
      @language = value.presence || DEFAULT_LANGUAGE
    end

  end
end
