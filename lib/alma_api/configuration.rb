module AlmaApi
  class Configuration

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
      base_url = value.presence || "https://api-eu.hosted.exlibrisgroup.com/almaws/v1"
      @base_url = base_url&.ends_with?("/") ? base_url[0..-2] : base_url
    end

    def default_format=(value)
      @default_format = AlmaApi.validate_format!(value) || "json"
    end

    def language=(value)
      @language = value.presence || "en"
    end

  end
end
