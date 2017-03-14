require "spec_helper"

describe SwitchGear::CircuitBreaker do
  let(:circuit) do
    ->(arg) { service(arg) }
  end
  let(:breaker) do
    SwitchGear::CircuitBreaker::Memory.new do |cb|
      cb.circuit = circuit
      cb.failure_limit = failure_limit
    end
  end
  context "#call" do
    it 'calls do_run with args and the circuit' do
      allow(breaker).to receive(:check_reset_timeout)
      allow(breaker).to receive(:open?).and_return(false)
      expect(breaker).to receive(:do_run).with([success], &circuit)
      breaker.call(success)
    end
    it 'raises an error if the breaker is open' do
      allow(breaker).to receive(:check_reset_timeout)
      allow(breaker).to receive(:open?).and_return(true)
      expect {
        breaker.call(failure)
      }.to raise_error(SwitchGear::CircuitBreaker::OpenError)
    end
    it 'checks if the reset_timeout has lapsed and if so changes the state' do
      allow(breaker).to receive(:open?).and_return(true, false)
      allow(breaker).to receive(:reset_period_lapsed?).and_return(true)

      expect(breaker).to receive(:state=).with(:half_open)
      expect(breaker).to receive(:state=).with(:closed)
      breaker.call(success)
    end
  end
  context "#failure_count" do
    it 'returns an integer' do
      failures = 2
      failures.times { breaker.call(failure) }
      expect(breaker.failure_count).to eq failures
    end
  end
  [:open, :closed, :half_open].each do |state|
    context "##{state}?" do
      it 'returns a bool' do
        allow(breaker).to receive(:state).and_return(state)
        expect(breaker.send("#{state}?")).to eq true
      end
    end
  end
  context "class needs to implement" do
    let(:breaker) do
      Helpers::MyAdapter.new do |a|
        a.circuit = -> { }
      end
    end
    context 'getters' do
      [:failures, :state].each do |method|
        it "must implement #{method}" do
          expect {
            breaker.send(method)
          }.to raise_error(NotImplementedError)
        end
      end
    end
    context 'setters' do
      [:failures=, :add_failure, :state=].each do |method|
        it "must implement #{method}" do
          expect {
            breaker.send(method, "arg")
          }.to raise_error(NotImplementedError)
        end
      end
    end
    context "validations" do
      it 'requires logging level methods if using a custom logger' do
        breaker =  Helpers::MyAdapter.new do |cb|
          cb.circuit = -> { }
          cb.logger = double('bad logger')
        end
        expect {
          breaker.run_validations
        }.to raise_error(NotImplementedError, "Your logger must respond to [:debug, :info, :warn, :error]")
      end
      it 'requires the circuit be callable' do
        breaker = Helpers::MyAdapter.new { |cb| cb.circuit = :some_method }
        expect {
          breaker.run_validations
        }.to raise_error(NotImplementedError, "Your circuit must respond to #call")
      end
    end
  end
end
