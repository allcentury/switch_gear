class CircuitBreaker
  module Adapters
    def build_from(name, client = nil, namespace = nil)
      case name
      when :redis
        Redis.new(client: client, namespace: namespace)
      when :memory
        Memory.new
      else
        msg = "You're trying to use an unknown adapter, currently we support: #{adapters}"
        raise NotImplementedError.new(msg)
      end
    end

    private

    def adapters
      [:redis, :memory]
    end
  end
end
