require 'switch_gear/circuit_breaker'
require 'logger'

@logger = Logger.new(STDOUT)

handles = ["joe", "jane", "mary", "steve"]

def get_tweets(twitter_handle)
  http_result = ["Success!", "Fail"].sample
  raise RuntimeError.new("Failed to fetch tweets for #{twitter_handle}") if http_result == "Fail"
  @logger.info "#{http_result} getting tweets for #{twitter_handle}"
end

breaker = SwitchGear::CircuitBreaker::Memory.new do |cb|
  cb.circuit = -> (twitter_handle) { get_tweets(twitter_handle) }
  cb.failure_limit = 2
  cb.reset_timeout = 5
end

handles.each do |handle|
  begin
    breaker.call(handle)
  rescue SwitchGear::CircuitBreaker::OpenError
    @logger.warn "Circuit is open - unable to make calls for #{handle}"
    sleep breaker.reset_timeout
  end
end
