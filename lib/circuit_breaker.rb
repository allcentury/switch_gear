require "circuit_breaker/version"
require "circuit_breaker/failure"
require 'logger'

class CircuitBreaker
  class Open < StandardError; end

  attr_reader :failures, :state
  attr_accessor :circuit, :failure_limit, :reset_timeout, :logger

  def initialize(&block)
    yield self
    @failures = []
    @state = :closed
    @reset_timeout ||= 10
    @logger ||= Logger.new(STDOUT)
    run_validations
  end

  def call(*args)
    check_reset_timeout
    raise Open if open?
    do_run(args, &circuit)
  end

  def failure_count
    failures.size
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

  def do_run(args)
    yield *args
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
    logger.info "Circuit closed"
  end

  def handle_failure(e)
    failure = Failure.new(e)
    failures << failure
    logger.warn failure.to_s
    if half_open? || failures.size >= failure_limit
      @state = :open
    else
      @state = :closed
    end
  end

  def run_validations
    logger_methods = [:debug, :info, :warn, :error]
    if !logger_methods.all? { |e| logger.respond_to?(e) }
      raise NotImplementedError.new("Your logger must respond to #{logger_methods}")
    end
    if !circuit.respond_to?(:call)
      raise NotImplementedError.new("Your circuit must respond to #call")
    end
  end
end
