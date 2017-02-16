require 'spec_helper'

describe CircuitBreaker::Memory do
  let(:breaker) do
    described_class.new do |cb|
      cb.circuit = -> (arg) { service(arg) }
    end
  end
  describe '#defaults' do
    it 'defaults to :closed' do
      expect(breaker.closed?).to eq true
    end
  end
  describe 'failed calls' do
    let(:breaker) do
      described_class.new do |cb|
        cb.circuit = -> (arg) { service(arg) }
        cb.failure_limit = failure_limit
      end
    end
    let(:failure_limit) { 1 }
    it "records failures" do
      breaker.call(failure)
      expect(breaker.failure_count).to eq 1
    end
    it 'will not make calls and raise an error when failure limit is reached' do
      failure_limit.times { breaker.call(failure) }

      expect(breaker.failure_count).to eq failure_limit
      expect(breaker.open?).to eq true
      expect { breaker.call(failure) }.to raise_error(CircuitBreaker::OpenError)
    end
  end
  describe 'resetting' do
    let(:breaker) do
      described_class.new do |cb|
        cb.circuit = -> (arg) { service(arg) }
        cb.failure_limit = failure_limit
      end
    end
    it 'resets failures when successful' do
      # fail once
      breaker.call(failure)
      # succeed
      breaker.call(true)

      expect(breaker.failure_count).to eq 0
      expect(breaker.open?).to eq false
    end
    it 'resets when a failure has passed reset_timeout' do
      # breaker will allow calls again after 0.5 second
      Timecop.freeze(Time.now)
      reset_timeout = 0.5
      breaker = described_class.new do |cb|
        cb.circuit = -> (arg) { service(arg) }
        cb.failure_limit = failure_limit
        cb.reset_timeout = reset_timeout
      end

      failure_limit.times { breaker.call(failure) }
      expect(breaker.open?).to eq true
      Timecop.travel(reset_timeout)

      # try again without a failure
      breaker.call(success)
      expect(breaker.open?).to eq false
      expect(breaker.closed?).to eq true
      expect(breaker.failure_count).to eq 0
    end
  end
  describe 'state half open' do
    before(:each) do
      # breaker will allow calls again after 0.5 second
      Timecop.freeze(Time.now)
      reset_timeout = 0.5
      @breaker = described_class.new do |cb|
        cb.circuit = -> (arg) { service(arg) }
        cb.failure_limit = failure_limit
        cb.reset_timeout = reset_timeout
      end

      failure_limit.times { |i| @breaker.call(failure) }
      expect(@breaker.open?).to eq true
      Timecop.travel(reset_timeout)
    end
    it 'changes state to half open when reset_timeout is exceeded' do
      # we don't want to check the value of state before #reset_failure is called
      # so we stub it out before it can overwrite @state
      allow(@breaker).to receive(:reset_failures)
      @breaker.call(success)
      expect(@breaker.half_open?).to eq true
    end
    it 'changes back to open after a successful call' do
      @breaker.call(success)
      expect(@breaker.closed?).to eq true
    end
  end
end
