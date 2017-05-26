module SwitchGear
  module CircuitBreaker
    class Memory
      include CircuitBreaker

      # The main runner, must respond to #call
      # @return [Proc/Lambda] the runner
      attr_accessor :circuit
      # The count of failures
      # @return [Integer] the amount of failures to permit.  Defaults to 10 seconds.
      attr_accessor :failure_limit
      # The amount of time in seconds before a breaker should reset if currently open.  Defaults to 5.
      # @return [Integer]
      attr_accessor :reset_timeout
      # The current logger
      # @return [Object] - The logger sent in at initialization.  Defaults to ruby's std Logger class.
      attr_accessor :logger
      # The current state
      # @return [Symbol] should always return either :open, :closed or :half-open.
      #   Use the helper methods in lib/circuit_breaker.rb for more readable code.
      attr_accessor :state
      # The current failures
      # @return [Array<CircuitBreaker::Failure>] - a list of failures serialized.
      attr_accessor :failures
      #
      # @example create a new breaker
      #   breaker = SwitchGear::CircuitBreaker::Memory.new do |cb|
      #     cb.circuit = -> (arg) { my_method(arg) }
      #     cb.failure_limit = 2
      #     cb.reset_timeout = 5
      #   end
      #
      # @yieldparam circuit - (look to {#circuit})
      # @yieldparam failure_limit - (look to {#failure_limit})
      # @yieldparam reset_timeout - (look to {#reset_timeout})
      # @yieldparam logger - (look to {#logger})
      # @return [SwitchGear::CircuitBreaker::Memory] the object.
      def initialize(&block)
        yield self
        @failure_limit ||= 5
        @reset_timeout ||= 10
        @logger ||= Logger.new(STDOUT)
        @state = :closed
        @failures = []
        run_validations
      end

      # (look to {SwitchGear::CircuitBreaker::add_failure})
      def add_failure(failure)
        failures << failure
      end

    end
  end
end
