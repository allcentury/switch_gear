require 'spec_helper'

describe CircuitBreaker::Adapters::Memory do
  let(:breaker) do
    CircuitBreaker.new do |cb|
      cb.circuit = -> (arg) { service(arg) }
    end
  end
  it 'holds failures in memory' do
    breaker.call(failure)
    expect(breaker.failure_count).to eq 1
  end
end
