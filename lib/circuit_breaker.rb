require "circuit_breaker/version"
require "circuit_breaker/failure"
require 'pry'

class CircuitBreaker
  class Open < StandardError; end

  attr_reader :failures, :state
  attr_accessor :circuit, :failure_limit, :reset_timeout

  def initialize(&block)
    yield self
    @failures = []
    @state = :closed
    @reset_timeout ||= 10
  end

  def call(arg)
    check_reset_timeout
    raise Open if open?
    do_run(arg, &circuit)
  end

  def failure_count
    @failures.size
  end

  def open?
    state == :open
  end

  def closed?
    state == :closed
  end

  def half_open?
    state == :half_open
  end

  private

  def do_run(arg)
    yield arg
    reset_failures
  rescue => e
    handle_failure(e)
  end

  def check_reset_timeout
    return if !open?
    if reset_period_lapsed?
      @state = :half_open
    end
  end

  def reset_period_lapsed?
    (Time.now.utc - failures.last.timestamp) > reset_timeout
  end

  def reset_failures
    @failures = []
    @state = :closed
  end

  def handle_failure(e)
    @failures << Failure.new(e)
    if half_open? || failures.size >= failure_limit
      @state = :open
    else
      @state = :closed
    end
  end
end
