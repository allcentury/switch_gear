module CircuitBreaker

  class Redis
    include CircuitBreaker
    attr_accessor :circuit, :failure_limit, :reset_timeout, :logger,
                  :state, :failures, :namespace, :client

    # The main class to instantiate the CircuitBraker class.
    #
    # @example create a new breaker
    #   breaker = CircuitBreaker.new do |cb|
    #     cb.circuit = -> (arg) { my_method(arg) }
    #     cb.failure_limit = 2
    #     cb.reset_timeout = 5
    #     cb.client = redis_client
    #     cb.namespace = "some_key"
    #   end
    #
    # @yieldparam circuit [Proc/Lambda] The method you'll want to invoke within a breaker
    # @yieldparam failure_limit [Integer] The maximum amount of failures you'll tolerate in a row before the breaker is tripped. Defaults to 5.
    # @yieldparam reset_timeout [Integer] The amount of time before the breaker should move back to closed after the last failure.  For instance if you set this to 5, the breaker is callable again 5+ seconds after the last failure.  Defaults to 10 seconds
    # @yieldparam logger [Logger] A logger instance of your choosing.  Defaults to ruby's std logger.
    # @yieldparam client [Object] - an instance of an redis client.  This library does not have a hard dependency on a particular redis client but for testing I've used [redis-rb](https://github.com/redis/redis-rb).  Whatever you pass in here simply has to implement a few redis commands such as `sadd`, `del`, `smembers`, `get` and `set`.  The client will ensure these exist before the breaker can be instantiated.
    # @yieldparam namespace [String] A unique name that will be used across servers to sync `state` and `failures`.  I'd recommend `your_class.name:your_method_name` or whatever is special about what's being invoked in the `circuit`.  See examples/example_redis.rb
    #
    # @return [CircuitBreaker] the object.
    def initialize
      yield self
      @client = client
      @namespace = namespace
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
