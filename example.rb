require 'circuit_breaker'
require 'logger'
require 'redis'
require 'pry'

@logger = Logger.new(STDOUT)

handles = ["joe", "jane", "mary", "steve"]

def get_tweets(twitter_handle, num)
  http_result = ["Success!", "Fail"].sample
  raise RuntimeError.new("Failed to fetch tweets for #{twitter_handle}") if http_result == "Fail"
  @logger.info "#{http_result} getting tweets for #{twitter_handle}"
end

redis = Redis.new

breaker = CircuitBreaker.new do |cb|
  cb.circuit = -> (twitter_handle, num) { get_tweets(twitter_handle, num) }
  cb.adapter = :redis
  cb.adapter_client = redis
  cb.adapter_namespace = "get_tweets"
  cb.failure_limit = 2
  cb.reset_timeout = 5
end

handles.each_with_index do |handle, i|
  begin
    breaker.call(handle, i)
  rescue CircuitBreaker::Open
    sleep breaker.reset_timeout
  end
end
