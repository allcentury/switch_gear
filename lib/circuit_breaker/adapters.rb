class CircuitBreaker
  module Adapters
    def build_from(name, client, namespace)
      case name
      when :redis
        Redis.new(client: client, namespace: namespace)
      else
        Memory.new
      end
    end
  end
end
