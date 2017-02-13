# CircuitBreaker

A lightweight ruby gem that implements the famous Michael Nygard circuit breaker pattern.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'circuit_breaker'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install circuit_breaker

## Usage

Here's an example of how you could use the breaker while making routine calls to a third party service such as Twitter:

```ruby
require 'circuit_breaker'
require 'logger'

@logger = Logger.new(STDOUT)

handles = ["joe", "jane", "mary", "steve"]

def get_tweets(twitter_handle)
  http_result = ["Success!", "Fail"].sample
  raise RuntimeError.new("Failed to fetch tweets for #{twitter_handle}") if http_result == "Fail"
  @logger.info "#{http_result} getting tweets for #{twitter_handle}"
end

breaker = CircuitBreaker.new do |cb|
  cb.circuit = -> (twitter_handle) { get_tweets(twitter_handle) }
  cb.failure_limit = 2
  cb.reset_timeout = 5
end

handles.each do |handle|
  begin
    breaker.call(handle)
  rescue CircuitBreaker::Open
    sleep breaker.reset_timeout
  end
end
```

You will see output similar to:
```
W, [2017-02-12T20:49:12.374971 #85900]  WARN -- : [RuntimeError] - Failed to fetch tweets for joe
W, [2017-02-12T20:49:12.375049 #85900]  WARN -- : [RuntimeError] - Failed to fetch tweets for jane
I, [2017-02-12T20:49:17.380771 #85900]  INFO -- : Success! getting tweets for steve
I, [2017-02-12T20:49:17.380865 #85900]  INFO -- : Circuit closed
```

Notice that we had two failures in a row for joe and jane.  The circuit breaker was configured to only allow for 2 failures via the `failuire_limit` method.  If another call comes in after two failures, it will raise a `CircuitBreaker::Open` error.  The only way the circuit breaker will be closed again is if the `reset_timeout` period has lapsed.  In our loop we catch the `CircuitBreaker::Open` exception and sleep (don't sleep in production - this is just an example) to allow the Circuit to close.  You can see the timestamp of this log,

```
I, [2017-02-12T20:49:17.380771 #85900]  INFO -- : Success! getting tweets for steve
```
is 5+ seconds after the last error which exceeds the `reset_timeout` - that's why the breaker allowed the method invocation to go get steve's tweets.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/allcentury/circuit_breaker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
