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

  class DummyLogger; end
end
