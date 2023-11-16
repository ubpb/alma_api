require "test_helper"

module AlmaApi
  class ConfigurationTest < Minitest::Test

    def test_initialize_with_defaults
      config = AlmaApi::Configuration.new

      assert_nil config.api_key
      assert_equal "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", config.base_url
      assert_equal "json", config.default_format
      assert_equal "en", config.language
    end

    def test_api_key_setter
      config = AlmaApi::Configuration.new

      config.api_key = "1234"
      assert_equal "1234", config.api_key

      config.api_key = nil
      assert_nil config.api_key

      config.api_key = ""
      assert_nil config.api_key
    end

    def test_base_url_setter_with_symbol
      config = AlmaApi::Configuration.new

      config.base_url = :na
      assert_equal "https://api-na.hosted.exlibrisgroup.com/almaws/v1", config.base_url

      config.base_url = nil
      assert_equal "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", config.base_url
    end

    def test_base_url_setter_with_string
      config = AlmaApi::Configuration.new

      config.base_url = "https://api-eu.hosted.exlibrisgroup.com/foo"
      assert_equal "https://api-eu.hosted.exlibrisgroup.com/foo", config.base_url

      config.base_url = nil
      assert_equal "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", config.base_url

      config.base_url = ""
      assert_equal "https://api-eu.hosted.exlibrisgroup.com/almaws/v1", config.base_url
    end

    def test_default_format_setter
      config = AlmaApi::Configuration.new

      config.default_format = "xml"
      assert_equal "xml", config.default_format

      config.default_format = "json"
      assert_equal "json", config.default_format

      config.default_format = nil
      assert_equal "json", config.default_format

      config.default_format = ""
      assert_equal "json", config.default_format

      assert_raises(ArgumentError) { config.default_format = "unsupported" }
    end

    def test_language_setter
      config = AlmaApi::Configuration.new

      config.language = "de"
      assert_equal "de", config.language

      config.language = nil
      assert_equal "en", config.language

      config.language = ""
      assert_equal "en", config.language
    end

  end
end
