class CircuitBreaker
  module Adapters
    class Memory
      attr_accessor :state, :failures
      def initialize
        @state = :closed
        @failures = []
      end

      def add_failure(failure)
        failures << failure
      end
    end
  end
end
