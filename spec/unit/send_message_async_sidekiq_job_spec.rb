require 'spec_helper.rb'

describe Pwwka::SendMessageAsyncSidekiqJob do
  describe "#perform" do
    before do
      allow(Pwwka::Transmitter).to receive(:send_message!)
    end

    context "with just two arguments" do
      it "calls through to Pwwka::Transmitter, setting error handling to 'raise'" do
        described_class.new.perform({ "foo" => "bar"} , "some.routing.key")
        expect(Pwwka::Transmitter).to have_received(:send_message!).with(
          { "foo" => "bar" },
          "some.routing.key",
          type: nil,
          message_id: :auto_generate,
          headers: nil,
          on_error: :raise
        )
      end
    end

    context "with optional values" do
      it "passes them through to Pwwka::Transmitter" do
        described_class.new.perform(
          { "foo" => "bar"},
          "some.routing.key",
          "type" =>  "Customer",
          "message_id" =>  "foobar",
          "headers" =>  { "x" => "y" }
        )
        expect(Pwwka::Transmitter).to have_received(:send_message!).with(
          { "foo" => "bar" },
          "some.routing.key",
          type: "Customer",
          message_id: "foobar",
          headers: { "x" => "y" },
          on_error: :raise
        )
      end
    end
  end
end
