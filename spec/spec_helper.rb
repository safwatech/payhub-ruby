# frozen_string_literal: true

require "payhub"
require "webmock/rspec"
require "json"
require "base64"
require "pathname"

WebMock.disable_net_connect!(allow_localhost: false)

VECTORS_PATH = Pathname.new(__dir__).join("..", "..", "shared", "test-vectors")

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
