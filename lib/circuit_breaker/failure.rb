class CircuitBreaker
  class Failure
    attr_reader :error, :recorded
    def initialize(error)
      @error = error
      @recorded = Time.now
    end

    def to_s
      errror.to_s
    end
  end
end
