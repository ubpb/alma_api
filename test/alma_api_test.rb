require "test_helper"

class AlmaApiTest < Minitest::Test

  def test_configure_deprecated
    assert_output(nil, /deprecated/) do
      AlmaApi.configure do |c|
        c.api_key = "1234"
      end
    end
  end

  def test_validate_format
    assert_equal "json", AlmaApi.validate_format!("json")
    assert_equal "xml", AlmaApi.validate_format!("xml")
    assert_nil AlmaApi.validate_format!(nil)
    assert_nil AlmaApi.validate_format!("")

    assert_raises(ArgumentError) { AlmaApi.validate_format!("unsupported") }
  end

end
