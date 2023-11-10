require "simplecov"
require "simplecov_json_formatter"
SimpleCov.start do
  add_filter "/test/"
end

require "minitest/autorun"
require "webmock/minitest"
require "debug"

require "alma_api"
