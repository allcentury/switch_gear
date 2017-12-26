require "switch_gear/circuit_breaker/failure"
require 'switch_gear/circuit_breaker/open_error'
require 'switch_gear/circuit_breaker/memory'
require 'switch_gear/circuit_breaker/redis'
require 'logger'

module SwitchGear
  module CircuitBreaker
    # Calls the circuit proc/lambda if the circuit is closed or half-open.
    #
    # @param args [Array<Object>] Any number of Objects to be called with the circuit block.
    # @return [Void, SwitchGear::CircuitBreaker::Open] No usable return value if successful, but will raise an error if failure_limit is reached or if the circuit is open
    def call(*args)
      check_reset_timeout
      raise OpenError if open?
      do_run(args, &circuit)
    end

    # @return most recent failure [SwitchGear::CircuitBreaker::Failure]
    def most_recent_failure
      failures.last
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

    # @return [Array<SwitchGear::CircuitBreaker::Failure>] a list of current failures
    def failures
      must_implement(:failures)
    end

    # @param failure [Array<SwitchGear::CircuitBreaker::Failure>] a list of failures
    # @return [void]
    def failures=(failure)
      must_implement(:failures=)
    end

    # @param failure [SwitchGear::CircuitBreaker::Failure] a list of failures
    # @return [void]
    def add_failure(failure)
      must_implement(:add_failure)
    end

    # @return [Symbol] - either :open, :closed, :half-open
    def state
      must_implement(:state)
    end

    # @param state [Symbol] - either :open, :closed, :half-open
    # @return [void]
    def state=(state)
      must_implement(:state=)
    end

    private

    def must_implement(arg)
      raise NotImplementedError.new("You must implement #{arg}.")
    end

    def do_run(args)
      yield *args
      reset_failures
    rescue => e
      handle_failure(e)
    end

    def check_reset_timeout
      return if !open?
      if failure_count == 0 || reset_period_lapsed?
        self.state = :half_open
      end
    end

    def reset_period_lapsed?
      (Time.now.utc - most_recent_failure.timestamp) > reset_timeout
    end

    def reset_failures
      self.failures = []
      self.state = :closed
      logger.info "Circuit closed"
    end

    def handle_failure(e)
      failure = Failure.new(e)
      add_failure(failure)
      logger.warn failure.to_s
      if half_open? || failure_count >= failure_limit
        self.state = :open
      else
        self.state = :closed
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
end
