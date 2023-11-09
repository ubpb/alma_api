require "test_helper"

class AlmaApiTest < Minitest::Test

  def test_configure
    client = AlmaApi.configure do |config|
      config.api_key = "1234"
      config.base_url = "BASE_URL"
      config.default_format = "json"
      config.language = "de"
    end

    assert_equal "1234", client.configuration.api_key
    assert_equal "BASE_URL", client.configuration.base_url
    assert_equal "json", client.configuration.default_format
    assert_equal "de", client.configuration.language
  end

  def test_validate_format
    assert_equal "json", AlmaApi.validate_format!("json")
    assert_equal "xml", AlmaApi.validate_format!("xml")
    assert_nil AlmaApi.validate_format!(nil)

    assert_raises(ArgumentError) { AlmaApi.validate_format!("unsupported") }
    assert_raises(ArgumentError) { AlmaApi.validate_format!("") }
  end

end
