$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "circuit_breaker"
require_relative "helpers"

RSpec.configure do |c|
  c.include Helpers
end
