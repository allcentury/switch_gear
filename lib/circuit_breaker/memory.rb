module CircuitBreaker
  class Memory
    include CircuitBreaker
    attr_accessor :circuit, :failure_limit, :reset_timeout, :logger, :state, :failures
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
    # @return [CircuitBreaker::Memory] the object.
    def initialize(&block)
      yield self
      @failure_limit ||= 5
      @reset_timeout ||= 10
      @logger ||= Logger.new(STDOUT)
      @state = :closed
      @failures = []
      run_validations
    end

    def add_failure(failure)
      failures << failure
    end

  end
end
