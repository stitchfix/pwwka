require "spec_helper"

describe Pwwka::ErrorHandlers::Chain do
  subject(:chain) { described_class.new(default_handler_chain) }

  describe "#handle_error" do
    context "when an error handler raises an unhandled exception" do
      let(:default_handler_chain) { [bad_error_handler_klass, good_error_handler_klass] }
      let(:bad_error_handler_klass) { double("bad error handler klass", new: bad_error_handler) }
      let(:bad_error_handler) {
        handler = double("bad error handler")
        allow(handler).to receive(:handle_error).and_raise("unhandled exception in error handler")
        handler
      }
      let(:good_error_handler_klass) { double("good error handler klass") }

      before { allow(bad_error_handler).to receive(:error_handler).and_raise("Wibble") }

      it "does not run subsequent error handlers" do
        expect(good_error_handler_klass).to_not receive(:new)

        expect {
          chain.handle_error(double,double,double,double,double,double.as_null_object)
        }.to raise_error(SystemExit)
      end

      it "aborts the process" do
        expect {
          chain.handle_error(double,double,double,double,double,double.as_null_object)
        }.to raise_error(SystemExit)
      end

      it "logs exceptions that occur in the error handling chain" do
        expect(chain.logger).to receive(:send).with(any_args).exactly(2).times
        expect(chain.logger).to receive(:send).with(:fatal, /aborting due to unhandled exception/)

        expect {
          chain.handle_error(double,double,double,double,double,double.as_null_object)
        }.to raise_error(SystemExit)
      end
    end
  end
end
