require "circuit_breaker/version"
require "circuit_breaker/failure"
require 'logger'

class CircuitBreaker
  class Open < StandardError; end

  attr_reader :failures, :state
  attr_accessor :circuit, :failure_limit, :reset_timeout, :logger

  # The main class to instantiate the CircuitBraker class.
  #
  # @example create a new breaker
  #   breaker = CircuitBreaker.new do |cb|
  #     cb.circuit = -> (arg) { my_method(arg) }
  #     cb.failure_limit = 2
  #     cb.reset_timeout = 5
  #   end
  #
  # @yieldparam circuit [Proc/Lambda] The method you'll want to invoke within a breaker
  # @yieldparam failure_limit [Integer] The maximum amount of failures you'll tolerate in a row before the breaker is tripped. Defaults to 5.
  # @yieldparam reset_timeout [Integer] The amount of time before the breaker should move back to closed after the last failure.  For instance if you set this to 5, the breaker is callable again 5+ seconds after the last failure.  Defaults to 10 seconds
  # @yieldparam logger [Logger] A logger instance of your choosing.  Defaults to ruby's std logger.
  #
  # @return [CircuitBreaker] the object.
  def initialize(&block)
    yield self
    @failures = []
    @state = :closed
    @failure_limit ||= 5
    @reset_timeout ||= 10
    @logger ||= Logger.new(STDOUT)
    run_validations
  end

  # Calls the circuit proc/lambda if the circuit is closed or half-open
  #
  # @param args [Array<Object>] Any number of Objects to be called with the circuit block.
  # @return [Void, CircuitBreaker::Open] No usable return value if successful, but will raise an error if failure_limit is reached.
  def call(*args)
    check_reset_timeout
    raise Open if open?
    do_run(args, &circuit)
  end

  # @return [Integer] The count of current failures
  def failure_count
    failures.size
  end

  # @return [Boolean] Whether the circuit is open
  def open?
    state == :open
  end

  # @return [Boolean] Whether the circuit is closed
  def closed?
    state == :closed
  end

  # @return [Boolean] Whether the circuit is half-open
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
