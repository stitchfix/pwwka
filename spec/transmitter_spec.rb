require 'spec_helper.rb'

describe Pwwka::Transmitter do

  before(:all) do
    @test_handler = Pwwka::TestHandler.new
    @test_handler.test_setup
  end

  after(:all) { @test_handler.test_teardown }

  let(:payload)     { Hash[:this, "that"] }
  let(:routing_key) { "this.that" }

  describe "#send_message!" do

    it "should send the correct payload" do
      success = Pwwka::Transmitter.new.async.send_message!(payload, routing_key)
      expect(success).to be_truthy
      received_payload = @test_handler.get_topic_message_payload_for_tests
      expect(received_payload["this"]).to eq("that")
    end

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      expect {
        Pwwka::Transmitter.new.async.send_message!(payload, routing_key)
      }.to raise_error
    end

  end

  describe "::send_message!" do

    it "should send the correct payload" do
      Pwwka::Transmitter.send_message!(payload, routing_key)
      received_payload = @test_handler.get_topic_message_payload_for_tests
      expect(received_payload["this"]).to eq("that")
    end

    it "should use sucker_punch to send the message in the background" do
      expect_any_instance_of(Pwwka::Transmitter).to receive(:send_message!).with(payload, routing_key).and_return(true)
      Pwwka::Transmitter.send_message!(payload, routing_key)
    end

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      expect{
        Pwwka::Transmitter.send_message!(payload, routing_key)
      }.to raise_error
    end

  end

  describe "::send_message_safely" do

    it "should send the correct payload" do
      Pwwka::Transmitter.send_message_safely(payload, routing_key)
      received_payload = @test_handler.get_topic_message_payload_for_tests
      expect(received_payload["this"]).to eq("that")
    end

    it "should not blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      Pwwka::Transmitter.send_message_safely(payload, routing_key)
      # check nothing has been queued
      expect(@test_handler.test_queue.pop.compact.count).to eq(0)
    end

  end

end
