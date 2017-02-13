$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "circuit_breaker"
require_relative "helpers"
require 'timecop'

RSpec.configure do |c|
  c.include Helpers
  c.after(:each) do
    Timecop.return
  end
end
