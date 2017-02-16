module CircuitBreaker
  class Redis
    include CircuitBreaker
    attr_accessor :circuit, :failure_limit, :reset_timeout, :logger, :state, :failures, :namespace, :client
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
      self.state = :closed
    end

    def state=(state)
      client.set(state_namespace, state.to_s)
    end

    def failures
      redis_fails = client.smembers(fail_namespace)
      return redis_fails.map { |f| Failure.from_json(f) } if redis_fails
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
