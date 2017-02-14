class CircuitBreaker
  module Adapters
    class Redis
      attr_reader :client, :namespace
      def initialize(client:, namespace:)
        @client = client
        @namespace = "circuit_breaker:#{namespace}"
      end

      def state
        redis_state = client.get(state_namespace)
        return redis_state.to_sym if redis_state
      end

      def state=(state)
        client.set(state_namespace, state.to_s)
      end

      def failures
        redis_fails = client.smembers(fail_namespace)
        return redis_fails.map { |f| Failure.from_json(f) } if redis_fails
      end

      def add_failure(failure)
        client.sadd(fail_namespace, failure.to_json)
      end

      def failures=(failures)
        client.del(fail_namespace)
      end

      private

      def fail_namespace
        "#{namespace}:failures"
      end

      def state_namespace
        "#{namespace}:state"
      end
    end
  end
end
