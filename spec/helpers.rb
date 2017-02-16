module Helpers
  def service(arg)
    raise arg if arg.is_a? StandardError
    arg
  end

  def open_then_close_breaker(breaker)
    failure_limit.times { |i| breaker.call(failure) }
    expect(breaker.open?).to eq true
    Timecop.travel(breaker.reset_timeout)
    breaker.call(success)
  end

  def failure_limit
    2
  end

  def failure
    StandardError.new(failure_msg)
  end

  def failure_msg
    "Remote system unavailable"
  end

  def success
    "success"
  end

  def error_class
    failure.class.to_s
  end

  class Redis
    def initialize
      redis_commands = [:smembers, :get, :set, :sadd, :del]
      redis_commands.each do |m|
        define_singleton_method m do
          m
        end
      end
    end
  end

  class MyAdapter
    include CircuitBreaker
    attr_accessor :circuit, :logger
    def initialize
      yield self
      @logger ||= Logger.new(STDOUT)
    end

    def run_validations
      super
    end
  end

  class DummyLogger; end
end
