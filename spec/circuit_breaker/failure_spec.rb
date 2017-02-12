require "spec_helper"

describe CircuitBreaker::Failure do
  let(:msg) { "Failed to read from remote" }
  let(:error) { StandardError.new(msg) }
  let(:failure) { described_class.new(error) }
  it 'records the time' do
    expect(failure.timestamp).to be_a Time
    expect(failure.timestamp.utc?).to eq true
  end
  it 'pretty prints' do
    expect(failure.to_s).to eq "[StandardError] - #{msg}"
  end
end
