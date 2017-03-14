require 'json'
module SwitchGear
  module CircuitBreaker
    class Failure
      def self.from_json(json)
        failure = JSON.parse(json)
        error = Object.const_get(failure["error"])
        error = error.new(failure["message"])
        new(error, Time.parse(failure["timestamp"]))
      end

      def initialize(error, recorded = Time.now.utc)
        @error = error
        @recorded = recorded
      end

      def timestamp
        recorded
      end

      def to_s
        "[#{error.class}] - #{error.message}"
      end

      def to_json
        JSON.generate({
          error: error.class,
          message: error.message,
          timestamp: timestamp.to_s
        })
      end

      private
      attr_reader :error, :recorded
    end
  end
end
