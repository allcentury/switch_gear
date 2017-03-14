require "spec_helper"

describe SwitchGear::CircuitBreaker::Failure do
  let(:msg) { "Failed to read from remote" }
  let(:error) { StandardError.new(msg) }
  let(:failure) { described_class.new(error) }
  it 'records the time' do
    expect(failure.timestamp).to be_a Time
    expect(failure.timestamp.utc?).to eq true
  end
  it '#to_s' do
    expect(failure.to_s).to eq "[StandardError] - #{msg}"
  end
  describe 'json' do
    let(:time) { Time.now }
    let(:json) do
      {
        error: error.class,
        message: error.message,
        timestamp: time.to_s
      }.to_json
    end
    before(:each) do
      time = Time.now.utc
      Timecop.freeze(time)
    end
    it '#to_json' do
      expect(failure.to_json).to eq json
    end
    it '.from_json' do
      failure = described_class.from_json(json)
      expect(failure).to be_a SwitchGear::CircuitBreaker::Failure
      expect(failure.to_s).to include "StandardError"
      expect(failure.timestamp).to be_a Time
    end
  end
end
