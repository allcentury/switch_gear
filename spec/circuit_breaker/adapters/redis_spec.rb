require 'spec_helper'

describe CircuitBreaker::Adapters::Redis do
  let(:client) { double('redis') }
  let(:namespace) { "service" }
  let(:state_namespace) { "circuit_breaker:#{namespace}:state" }
  let(:fail_namespace) { "circuit_breaker:#{namespace}:failures" }
  let(:closed) { "closed"}
  let(:open) { "open" }
  let(:breaker) do
    CircuitBreaker.new do |cb|
      cb.circuit = -> (arg) { service(arg) }
      cb.failure_limit = 1
      cb.adapter = :redis
      cb.adapter_client = client
      cb.adapter_namespace = namespace
    end
  end
  it 'registers the right adapter' do
    expect(breaker.adapter).to be_a described_class
  end
  describe 'writes and reads' do
    let(:timestamp) { "2017-02-13 23:31:31 UTC" }
    it 'holds state in redis' do
      expect(client).to receive(:get).exactly(3).with(state_namespace).and_return(closed)
      # this gets called after a successful call
      expect(client).to receive(:set).with(state_namespace, closed)
      expect(client).to receive(:del).with(fail_namespace)
      breaker.call(success)

      expect(breaker.adapter.state).to eq :closed
    end
    it 'holds failures in redis' do
      expect(client).to receive(:get).exactly(3).with(state_namespace).and_return(closed)
      time = Time.now.utc
      Timecop.freeze(time)
      expect(client).to receive(:smembers).with(fail_namespace).and_return([{error: "StandardError", timestamp: timestamp}.to_json])

      # this gets called after a failed call
      expect(client).to receive(:sadd).with(fail_namespace, { error: "StandardError", timestamp: time }.to_json)
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
    end
    it 'moves failures back to empty and state to closed after success' do
      expect(client).to receive(:get).exactly(5).with(state_namespace).and_return(closed)
      time = Time.now.utc
      Timecop.freeze(time)
      expect(client).to receive(:sadd).with(fail_namespace, { error: "StandardError", timestamp: time }.to_json)
      expect(client).to receive(:smembers).with(fail_namespace).and_return([{error: "StandardError", timestamp: timestamp}.to_json])
      expect(client).to receive(:set).with(state_namespace, open)
      breaker.call(failure)
      Timecop.travel(breaker.reset_timeout)

      expect(client).to receive(:set).with(state_namespace, closed)
      expect(client).to receive(:del).with(fail_namespace)
      breaker.call(success)
    end
  end
end

