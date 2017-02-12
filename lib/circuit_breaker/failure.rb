class CircuitBreaker
  class Failure
    def initialize(error)
      @error = error
      @recorded = Time.now.utc
    end

    def timestamp
      recorded
    end

    def to_s
      "[#{error.class}] - #{error.message}"
    end

    private
    attr_reader :error, :recorded
  end
end
