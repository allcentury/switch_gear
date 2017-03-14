module SwitchGear
  module CircuitBreaker
    class Redis
      include CircuitBreaker
      # (look to {SwitchGear::CircuitBreaker::Memory#circuit})
      attr_accessor :circuit
      # (look to {SwitchGear::CircuitBreaker::Memory#failure_limit})
      attr_accessor :failure_limit
      # (look to {SwitchGear::CircuitBreaker::Memory#reset_timeout})
      attr_accessor :reset_timeout
      # (look to {SwitchGear::CircuitBreaker::Memory#logger})
      attr_accessor :logger
      # (look to {SwitchGear::CircuitBreaker::Memory#state})
      attr_accessor :state
      # (look to {SwitchGear::CircuitBreaker::Memory#failures})
      attr_accessor :failures
      # A unique name that will be used across servers to
      # sync state and failures.  I'd recommend `your_class.name:your_method_name` or whatever
      # is special about what's being invoked in the `circuit`.  See examples/example_redis.rb
      # @return [String] - namespace given
      attr_accessor :namespace

      # An instance of an redis client.  This library does not have a
      # hard dependency on a particular redis client but for testing I've used
      # [redis-rb](https://github.com/redis/redis-rb).  Whatever you pass in here simply has to
      # implement a few redis commands such as `sadd`, `del`, `smembers`, `get` and `set`.
      # The client will ensure these exist before the breaker can be instantiated.
      # @return [Object] - redis client given
      attr_accessor :client

      # The main class to instantiate the CircuitBraker class.
      #
      # @example create a new breaker
      #   breaker = SwitchGear::CircuitBreaker::Redis.new do |cb|
      #     cb.circuit = -> (arg) { my_method(arg) }
      #     cb.failure_limit = 2
      #     cb.reset_timeout = 5
      #     cb.client = redis_client
      #     cb.namespace = "some_key"
      #   end
      #
      # @yieldparam circuit - (look to {#circuit})
      # @yieldparam failure_limit - (look to {#failure_limit})
      # @yieldparam reset_timeout - (look to {#reset_timeout})
      # @yieldparam logger - (look to {#logger})
      # @yieldparam client - (look to {#client})
      # @yieldparam namespace - (look to {#namespace})
      # @return [SwitchGear::CircuitBreaker::Redis] the object.
      def initialize
        yield self
        @client = client
        @namespace = namespace
        @failure_limit ||= 5
        @reset_timeout ||= 10
        @logger = Logger.new(STDOUT)
        run_validations
        @namespace = "circuit_breaker:#{namespace}"
      end

      def state
        redis_state = client.get(state_namespace)
        return redis_state.to_sym if redis_state
        # if there is no state stored in redis, set it.
        self.state = :closed
      end

      def state=(state)
        client.set(state_namespace, state.to_s)
      end

      def failures
        redis_fails = client.smembers(fail_namespace)
        return redis_fails.map { |f| Failure.from_json(f) } if redis_fails
        # if there are no failures in redis, set it to empty
        self.failures = []
        []
      end

      def add_failure(failure)
        client.sadd(fail_namespace, failure.to_json)
      end

      # failures= requires we replace what is currently in redis
      # with the new value so we delete all entries first then add
      def failures=(failures)
        client.del(fail_namespace)
        failures.each { |f| client.sadd(fail_namespace, f.to_json) }
      end

      private

      def fail_namespace
        "#{namespace}:failures"
      end

      def state_namespace
        "#{namespace}:state"
      end

      def run_validations
        # call super to ensure module has what it needs
        super
        redis_commands = [:smembers, :get, :set, :sadd, :del]
        if !redis_commands.all? { |c| client.respond_to?(c) }
          raise NotImplementedError.new("Missing Methods.  Your client must implement: #{redis_commands}")
        end
        if !namespace
          raise NotImplementedError.new("Missing namespace")
        end
      end
    end
  end
end
