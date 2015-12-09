require 'spec_helper.rb'

describe Pwwka::SendMessageAsyncJob do

  let(:payload) { Hash[:this, "that"] }
  let(:routing_key) { "this.that.and.theother" }

  describe '::perform' do
    it 'calls Pwwwka::Transmitter to send the message' do
      expect(Pwwka::Transmitter).to receive(:send_message!).with(payload, routing_key, on_error: :raise)
      described_class.perform(payload, routing_key)
    end
  end

end
