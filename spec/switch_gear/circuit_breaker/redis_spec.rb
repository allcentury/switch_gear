require 'spec_helper'

describe SwitchGear::CircuitBreaker::Redis do
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
  let(:default_breaker) do
    described_class.new do |cb|
      cb.circuit = -> {}
      cb.client = client
      cb.namespace = namespace
    end
  end
  before(:each) do
    redis_commands = [:rpush, :lindex, :llen, :del, :set, :get]
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
      @new_error = { error: error_class, message: failure_msg, timestamp: time.to_i }.to_json
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

      # this gets called after a failed call
      expect(client).to receive(:rpush).with(fail_namespace, @new_error)
      expect(client).to receive(:llen).with(fail_namespace).and_return(1)
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
    end
    it 'moves failures back to empty and state to closed after success' do
      expect(client).to receive(:get).exactly(5).with(state_namespace).and_return(closed)
      time = Time.now.utc
      Timecop.freeze(time)
      expect(client).to receive(:rpush).with(fail_namespace, @new_error)
      expect(client).to receive(:llen).with(fail_namespace).and_return(1)
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
      Timecop.travel(breaker.reset_timeout)

      expect(client).to receive(:set).with(state_namespace, closed)
      expect(client).to receive(:del).with(fail_namespace)
      breaker.call(success)
    end
    context "#most_recent_failure" do
      it "grabs from the LL tail" do
        expect(client).to receive(:lindex).with(fail_namespace, -1).and_return(@new_error)
        failure = default_breaker.most_recent_failure
        expect(failure).to be_a SwitchGear::CircuitBreaker::Failure
      end
    end
    context "#failures" do
      it "returns a list of failures" do
        allow(client).to receive(:llen).with(fail_namespace).and_return(1)
        expect(client).to receive(:lrange).with(fail_namespace, 0, -1).and_return([@new_error])
        failures = default_breaker.failures
        expect(failures).to be_a Array
        expect(failures.all? { |f| f.is_a?(SwitchGear::CircuitBreaker::Failure) }).to eq true
      end
    end
  end
  describe 'defaults' do
    it 'state if not present in redis' do
      expect(client).to receive(:get).with(state_namespace).and_return(nil)
      expect(client).to receive(:set).with(state_namespace, closed)
      expect(breaker.closed?).to eq true
    end
    it 'failures if not present in redis' do
      expect(client).to receive(:del).exactly(1).with(fail_namespace)
      # redis by default returns 0 for keys even if they don't exist
      expect(client).to receive(:llen).exactly(2).with(fail_namespace).and_return(0)
      expect(client).to_not receive(:lrange)
      expect(breaker.failure_count).to eq 0
      expect(breaker.failures).to eq []
    end
    it 'failure_limit of 5' do
      expect(default_breaker.failure_limit).to eq 5
    end
    it 'reset_timeout to 10 seconds' do
      expect(default_breaker.reset_timeout).to eq 10
    end
    it 'uses the ruby logger' do
      expect(default_breaker.logger).to be_a Logger
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
