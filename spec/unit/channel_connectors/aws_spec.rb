require 'spec_helper.rb'

# Most of this class is just interacting with Rabbit so it's covered
# by the integration tests.
describe Pwwka::ChannelConnectorAWS do
  let(:sqs_client_double) {
    Aws::SQS::Client.new(stub_responses: {
      get_queue_url: {
        queue_url: "https://example.org"
      },
      get_queue_attributes: {
        attributes: {
          "ApproximateNumberOfMessages" => "41"
        }
      },
      receive_message: {
        messages: [{
            message_id: "fake_message_id",
            body: '"fake_message_body"',
            attributes: {},
        }]
      }
    })
  }
  let(:sns_client_double) { Aws::SNS::Client.new(stub_responses: true) }

  before do
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client_double)
    allow(Aws::SNS::Client).to receive(:new).and_return(sns_client_double)
    ENV['AWS_REGION'] = 'us-east-1'
  end

  subject(:channel_connector) { described_class.new(queue_name: "testing") }

  describe "#initialize" do

    it "sets prefetch value if configured to do so" do
      expect(described_class.new(prefetch: 10).instance_variable_get(:@prefetch)).to eq(10)
      expect(described_class.new().instance_variable_get(:@prefetch)).to eq(1)
    end

    it "has a SQS client" do
      expect(channel_connector.instance_variable_get(:@sqs_client)).to be_an_instance_of(Aws::SQS::Client)
    end

    it "has a SNS client" do
      expect(channel_connector.instance_variable_get(:@sns_client)).to be_an_instance_of(Aws::SNS::Client)
    end

  end

  describe "#publish" do
    it "calls sns publish" do
      allow(channel_connector).to receive(:topic_arn).and_return("fake_arn")
      expect(sns_client_double).to(
        receive(:publish).
        with(
          hash_including(
            :message => "payload",
            :topic_arn => "fake_arn"
          )
        )
      )
      channel_connector.publish("payload", {})
    end
  end

  describe "#pop" do
    it "calls sns recieve_message and returns a message" do
      expect(sqs_client_double).to(
        receive(:receive_message)
      ).and_call_original
      message = channel_connector.pop
      expect(message).to be_an_instance_of(Pwwka::ChannelConnectorAWS::MessageAdapter)
      expect(message.payload).to eq("fake_message_body")
    end
  end

  describe "#subscribe" do
    it "polls for a messages" do
      called = false
      channel_connector.subscribe(manual_ack: true, block: false) { |message| called = true }
      expect(called).to be(true)
    end
  end

  describe "#nack" do
    it "calls sqs_client#delete_message" do
      expect(sqs_client_double).to(
        receive(:delete_message).
        with(
          hash_including(
            :receipt_handle => "123",
          )
        )
      )
      channel_connector.nack("123")
    end
  end

  describe "#ack" do
    it "calls sqs_client#delete_message" do
      expect(sqs_client_double).to(
        receive(:delete_message).
        with(
          hash_including(
            :receipt_handle => "123",
          )
        )
      )
      channel_connector.ack("123")
    end
  end

  describe "#message_count" do
    it "calls sqs client#get_queue_attributes" do
      expect(
        channel_connector.message_count
      ).to eq(41)

    end
  end
end
