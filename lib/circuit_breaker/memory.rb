module CircuitBreaker
  class Memory
    include CircuitBreaker
    attr_accessor :circuit, :failure_limit, :reset_timeout, :logger, :state, :failures
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
