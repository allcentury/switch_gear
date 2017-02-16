require 'spec_helper'

describe CircuitBreaker::Redis do
  let(:client) { double('redis') }
  let(:namespace) { "service" }
  let(:state_namespace) { "circuit_breaker:#{namespace}:state" }
  let(:fail_namespace) { "circuit_breaker:#{namespace}:failures" }
  let(:closed) { "closed"}
  let(:open) { "open" }
  let(:breaker) do
    described_class.new do |cb|
      cb.circuit = -> (arg) { service(arg) }
      cb.client = client
      cb.failure_limit = 1
      cb.namespace = namespace
    end
  end
  before(:each) do
    redis_commands = [:smembers, :get, :set, :sadd, :del]
    redis_commands.each do |c|
      allow(client).to receive(:respond_to?).with(c).and_return(true)
    end
  end
  describe 'writes and reads' do
    let(:timestamp) { "2017-02-13 23:31:31 UTC" }
    let(:failure_json) do
      { error: error_class, message: failure_msg, timestamp: timestamp }.to_json
    end
    before(:each) do
      time = Time.now.utc
      Timecop.freeze(time)
      @new_error = { error: error_class, message: failure_msg, timestamp: time }.to_json
    end
    it 'holds state in redis' do
      expect(client).to receive(:get).exactly(3).with(state_namespace).and_return(closed)
      # this gets called after a successful call
      expect(client).to receive(:set).with(state_namespace, closed)
      expect(client).to receive(:del).with(fail_namespace)
      breaker.call(success)

      expect(breaker.closed?).to eq true
    end
    it 'holds failures in redis' do
      expect(client).to receive(:get).exactly(3).with(state_namespace).and_return(closed)
      expect(client).to receive(:smembers).with(fail_namespace).and_return([failure_json])

      # this gets called after a failed call
      expect(client).to receive(:sadd).with(fail_namespace, @new_error)
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
    end
    it 'moves failures back to empty and state to closed after success' do
      expect(client).to receive(:get).exactly(5).with(state_namespace).and_return(closed)
      time = Time.now.utc
      Timecop.freeze(time)
      expect(client).to receive(:sadd).with(fail_namespace, @new_error)
      expect(client).to receive(:smembers).with(fail_namespace).and_return([failure_json])
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
      Timecop.travel(breaker.reset_timeout)

      expect(client).to receive(:set).with(state_namespace, closed)
      expect(client).to receive(:del).with(fail_namespace)
      breaker.call(success)
    end
  end
  describe 'defaults' do
    it 'defaults state if not present in redis' do
      expect(client).to receive(:get).with(state_namespace).and_return(nil)
      expect(client).to receive(:set).with(state_namespace, closed)
      expect(breaker.closed?).to eq true
    end
    it 'defaults failures if not present in redis' do
      expect(client).to receive(:del).exactly(2).with(fail_namespace)
      expect(client).to receive(:smembers).exactly(2).with(fail_namespace).and_return(nil)
      expect(breaker.failure_count).to eq 0
      expect(breaker.failures).to eq []
    end
  end
  describe 'validations' do
    it 'requires redis commands' do
      bad_client = double('bad redis client')
      expect {
        described_class.new do |cb|
          cb.circuit = -> (arg) { service(arg) }
          cb.failure_limit = 1
          cb.client = bad_client
          cb.namespace = namespace
        end
      }.to raise_error(NotImplementedError, /missing methods/i)
    end
    it 'requires a namespace' do
      expect {
        described_class.new do |cb|
          cb.circuit = -> (arg) { service(arg) }
          cb.failure_limit = 1
          cb.client = client
        end
      }.to raise_error(NotImplementedError, /missing namespace/i)
    end
  end
end
