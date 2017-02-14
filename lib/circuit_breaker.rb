require "circuit_breaker/version"
require "circuit_breaker/failure"
require 'circuit_breaker/adapters'
require 'circuit_breaker/adapters/memory'
require 'circuit_breaker/adapters/redis'
require 'logger'

class CircuitBreaker
  include Adapters
  class Open < StandardError; end

  attr_reader :failures, :state
  attr_accessor :circuit, :failure_limit, :reset_timeout, :logger, :adapter, :adapter_client, :adapter_namespace

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
  # @yieldparam adapter [Symbol] Which adapter to use,  ie `:redis` or `:memory`. Default is :memory
  # @yieldparam adapter_client [Object] - an instance of an adapter client.  This library does not have a hard dependency on a particular redis client but for testing I've used [redis-rb](https://github.com/redis/redis-rb).  Whatever you pass in here simply has to implement a few redis commands such as `sadd`, `del`, `smembers`, `get` and `set`.  The client will ensure these exist before the breaker can be instantiated.
  # @yieldparam adapter_namespace [String] A unique name that will be used across servers to sync `state` and `failures`.  I'd recommend `your_class.name}:some_method` or whatever is special about what's being invoked in the `circuit`.
  #
  # @return [CircuitBreaker] the object.
  def initialize(&block)
    yield self
    @adapter ||= :memory
    @adapter = build_from(adapter, adapter_client, adapter_namespace)
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
    adapter.state == :open
  end

  # @return [Boolean] Whether the circuit is closed
  def closed?
    adapter.state == :closed
  end

  # @return [Boolean] Whether the circuit is half-open
  def half_open?
    adapter.state == :half_open
  end

  # @return [Array<CircuitBreaker::Failure>] a list of current failures
  def failures
    adapter.failures
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
      adapter.state = :half_open
    end
  end

  def reset_period_lapsed?
    (Time.now.utc - adapter.failures.last.timestamp) > reset_timeout
  end

  def reset_failures
    adapter.failures = []
    adapter.state = :closed
    logger.info "Circuit closed"
  end

  def handle_failure(e)
    failure = Failure.new(e)
    adapter.add_failure(failure)
    logger.warn failure.to_s
    if half_open? || adapter.failures.size >= failure_limit
      adapter.state = :open
    else
      adapter.state = :closed
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
