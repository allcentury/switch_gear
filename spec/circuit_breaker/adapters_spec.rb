require 'spec_helper'

class DummyClass
  include CircuitBreaker::Adapters
end

describe CircuitBreaker::Adapters do
  let(:dummy) { DummyClass.new }
  it 'raises an error for an unknown adapter' do
    expect {
      dummy.build_from(:unknown_adapter)
    }.to raise_error(NotImplementedError)
  end
end
