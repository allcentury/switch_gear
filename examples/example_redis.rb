require 'circuit_breaker'
require 'logger'
require 'redis'
require 'pry'

@logger = Logger.new(STDOUT)

handles = ["joe", "jane", "mary", "steve"]

def get_tweets(twitter_handle, _num)
  http_result = ["Success!", "Fail"].sample
  raise RuntimeError.new("Failed to fetch tweets for #{twitter_handle}") if http_result == "Fail"
  @logger.info "#{http_result} getting tweets for #{twitter_handle}"
end

redis = Redis.new

breaker = CircuitBreaker::Redis.new do |cb|
  cb.circuit = -> (twitter_handle, num) { get_tweets(twitter_handle, num) }
  cb.client = redis
  cb.namespace = "get_tweets"
  cb.failure_limit = 2
  cb.reset_timeout = 5
end

handles.each_with_index do |handle, i|
  begin
    breaker.call(handle, i)
  rescue CircuitBreaker::OpenError
    sleep breaker.reset_timeout
  end
end