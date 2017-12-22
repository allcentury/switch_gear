# SwitchGear

>In an electric power system, switchgear is the combination of electrical disconnect switches, fuses or circuit breakers used to control, protect and isolate electrical equipment. Switchgears are used both to de-energize equipment to allow work to be done and to clear faults downstream. This type of equipment is directly linked to the reliability of the electricity supply.

SwitchGear is a module that will implement various failover protection layers for deploying apps at scale.  The first module is a lightweight implementation of the famous [Michael Nygard](https://www.martinfowler.com/bliki/CircuitBreaker.html) circuit breaker pattern.

## Installation

This gem is in alpha and is on RubyGems.org. I'm still finalizing the API, but if you wish to help me get to it's first stable release, please do!

Add this line to your application's Gemfile:

```ruby
gem 'switch_gear'
```

And then execute:

    $ bundle install

## Usage

### CircuitBreaker

#### In Memory

Here is an example of how you could use the breaker while making routine calls to a third party service such as Twitter:

```ruby
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
```

You will see output similar to:
```
W, [2017-02-12T20:49:12.374971 #85900]  WARN -- : [RuntimeError] - Failed to fetch tweets for joe
W, [2017-02-12T20:49:12.375049 #85900]  WARN -- : [RuntimeError] - Failed to fetch tweets for jane
I, [2017-02-12T20:49:17.380771 #85900]  INFO -- : Success! getting tweets for steve
I, [2017-02-12T20:49:17.380865 #85900]  INFO -- : Circuit closed
```

Notice that we had two failures in a row for joe and jane.  The circuit breaker was configured to only allow for 2 failures via the `failuire_limit` method.  If another call comes in after two failures, it will raise a `SwitchGear::CircuitBreaker::OpenError` error.  The only way the circuit breaker will be closed again is if the `reset_timeout` period has lapsed.  In our loop we catch the `SwitchGear::CircuitBreaker::OpenError` exception and sleep (don't sleep in production - this is just an example) to allow the Circuit to close.  You can see the timestamp of this log,

```
I, [2017-02-12T20:49:17.380771 #85900]  INFO -- : Success! getting tweets for steve
```
is 5+ seconds after the last error which exceeds the `reset_timeout` - that's why the breaker allowed the method invocation to go get steve's tweets.


#### Redis

In an distributed environment the in memory solution of the circuit breaker creates quite a bit of unnecessary work.  If you can imagine 5 servers all running their own circuit breakers, the `failure_limit` has just increased by a factor of 5. Ideally, we want server1's failures and server2's failures to be included for similar breakers.  We do this by using redis where the state of the breaker and the failures are persisted.  Redis is a great choice for this especially since most distributed systems have a redis instance in use.

You can visualize a few servers that were originally in a closed state moving to open upon failures as such:

![img](https://s3.postimg.org/stxckap03/ezgif_com_video_to_gif.gif)

You can set up the `CircuitBreaker` to use the redis adapter like this:

```ruby
breaker = SwitchGear::CircuitBreaker::Redis.new do |cb|
  cb.circuit = -> (twitter_handle) { get_tweets(twitter_handle) }
  cb.client = redis
  cb.namespace = "get_tweets"
  cb.failure_limit = 2
  cb.reset_timeout = 5
end
```

You need 2 additional parameters(compared to the `Memory` adapter), they are defined as such:

- `client` - an instance of a `Redis` client.  This gem does not have a hard dependency on a particular redis client but for testing I've used [redis-rb](https://github.com/redis/redis-rb).  Whatever you pass in here simply has to implement a few redis commands such as `sadd`, `del`, `smembers`, `get` and `set`.  The client will ensure these exist before the breaker can be instantiated.
- `namespace` - A unique name that will be used across servers to sync `state` and `failures`.  I'd recommend `class_name:some_method` or whatever is special about what's being invoked in the `circuit`.

#### Roll Your Own Circuit Breaker

The goal of this project is to help you implement a circuit breaker pattern and be agnostic to the persistence layer.  I did it in memory and in redis both as working implementations to make the gem usable out of the box.  There are other persitence stores that would work really well with this and you can roll your own simply by including the mixin.

```ruby
class MyPreferredStore
  include SwitchGear::CircuitBreaker
end
```
## Sidekiq

I've [written a middleware](https://github.com/allcentury/switch_gear_sidekiq-middleware) for use with Sidekiq.

## Forthcoming

1. A middleware in Sidekiq using this gem
2. Better in memory support for async tasks
3. More examples
4. More documentation


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/allcentury/circuit_breaker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
