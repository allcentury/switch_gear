require "spec_helper"

def spotty_service(_arg)
  fail RuntimeError
end

def healthy_service(arg)
  arg
end

describe CircuitBreaker do
  let(:failure_limit) { 2 }
  it "has a version number" do
    expect(CircuitBreaker::VERSION).not_to be nil
  end

  describe 'failed calls' do
    let(:breaker) do
      CircuitBreaker.new do |cb|
        cb.circuit = -> (arg) { spotty_service(arg) }
        cb.failure_limit = failure_limit
      end
    end

    it "records failures" do
      breaker.call(1)
      expect(breaker.failure_count).to eq 1
    end

    it 'will not make calls when failure limit is reached' do
      failure_limit.times { |i| breaker.call(i) }

      expect(breaker.failure_count).to eq failure_limit
      expect(breaker.open?).to eq true
      expect { breaker.call(2) }.to raise_error(CircuitBreaker::Open)
    end
  end

  describe 'resetting' do
    let(:breaker) do
      CircuitBreaker.new do |cb|
        cb.failure_limit = failure_limit
      end
    end
    it 'resets failures when successful' do
      # fail once
      breaker.circuit = -> (arg) { spotty_service(arg) }
      breaker.call(1)
      # succeed
      breaker.circuit = -> (arg) { healthy_service(arg) }
      breaker.call(1)

      expect(breaker.failure_count).to eq 0
      expect(breaker.open?).to eq false
    end
    it 'resets when a failure has passed reset_timeout' do
      # breaker will allow calls again after 1 second
      reset_timeout = 0.5
      breaker = CircuitBreaker.new do |cb|
        cb.circuit = -> (arg) { spotty_service(arg) }
        cb.failure_limit = failure_limit
        cb.reset_timeout = reset_timeout
      end

      failure_limit.times { |i| breaker.call(i) }
      expect(breaker.open?).to eq true
      sleep reset_timeout

      # try again
      breaker.circuit = -> (arg) { healthy_service(arg) }
      breaker.call(2)
      expect(breaker.open?).to eq false
      expect(breaker.closed?).to eq true
      expect(breaker.failure_count).to eq 0
    end
  end
  it 'changes state to half open when reset_timeout is exceeded' do
    # breaker will allow calls again after 1 second
    reset_timeout = 0.5
    breaker = CircuitBreaker.new do |cb|
      cb.circuit = -> (arg) { spotty_service(arg) }
      cb.failure_limit = failure_limit
      cb.reset_timeout = reset_timeout
    end

    failure_limit.times { |i| breaker.call(i) }
    expect(breaker.open?).to eq true
    sleep reset_timeout

    # call bad service again
    breaker.call(2)
    # breaker should be open
    expect(breaker.open?).to eq true
    expect(breaker.failure_count).to eq failure_limit + 1
  end
end
