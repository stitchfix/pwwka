require 'spec_helper'

describe Pwwka::MessageQueuer do

  let(:message_queuer)  { Pwwka::MessageQueuer.new }
  let(:message_queuer_with_messages) {
    Pwwka::MessageQueuer.new.queue_message(payload: payload1, routing_key: routing_key1)
      .queue_message(payload: payload2, routing_key: routing_key2)
  }
  let(:payload1)        { {this: 'that'} }
  let(:routing_key1)    { "thing.7.happened" }
  let(:payload2)        { {shim: 'sham'} }
  let(:routing_key2)    { "thing.8.happened" }

  describe "#queue_message" do

    it "should add a message to the queue" do
      expect(message_queuer.message_queue).to eq([])
      expect(
        message_queuer.queue_message(payload: payload1, routing_key: routing_key1)
          .queue_message(payload: payload2, routing_key: routing_key2).message_queue
      ).to eq([[payload1, routing_key1], [payload2, routing_key2]])
    end

  end


  describe "#send_messages_safely" do

    it "should send the queued messages" do
      expect(message_queuer_with_messages.message_queue).to eq([[payload1, routing_key1], [payload2, routing_key2]])
      expect(message_queuer_with_messages).to receive(:send_message_safely).with(payload1, routing_key1).and_call_original
      expect(message_queuer_with_messages).to receive(:send_message_safely).with(payload2, routing_key2).and_call_original
      expect(message_queuer_with_messages.send_messages_safely.message_queue).to eq([])
    end

  end

  describe "#send_messages!" do

    it "should send the queued messages" do
      expect(message_queuer_with_messages.message_queue).to eq([[payload1, routing_key1], [payload2, routing_key2]])
      expect(message_queuer_with_messages).to receive(:send_message!).with(payload1, routing_key1).and_call_original
      expect(message_queuer_with_messages).to receive(:send_message!).with(payload2, routing_key2).and_call_original
      expect(message_queuer_with_messages.send_messages!.message_queue).to eq([])
    end

  end

  describe "#clear_messages" do

    it "should clear the queued messages" do
      expect(message_queuer_with_messages.message_queue).to eq([[payload1, routing_key1], [payload2, routing_key2]])
      expect(message_queuer_with_messages.clear_messages.message_queue).to eq([])
    end

  end


end
