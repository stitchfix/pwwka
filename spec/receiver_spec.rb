require 'spec_helper.rb'

describe Pwwka::Receiver do

  class HandyHandler
    def self.handle!(delivery_info, properties, payload)
      return "made it here"
    end
  end

  let(:payload)     { { "this" => "that" } }
  let(:routing_key) { "this.that" }
  let(:queue_name)  { "receiver_test" }
  let(:logger)      { double(Logger) }

  describe "::subscribe" do

    before(:each) do
      @original_logger = Pwwka.configuration.logger
      Pwwka.configuration.logger = logger
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
      @receiver = Pwwka::Receiver.subscribe(HandyHandler, "receiver_test", block: false)
    end

    after(:each) do
      Pwwka.configuration.logger = @original_logger
      @receiver.test_teardown rescue nil
    end

    it "should receive the sent message and log about it" do
      expect(HandyHandler).to receive(:handle!).and_return("made it here")
      Pwwka::Transmitter.send_message!(payload, routing_key)
      expect(logger).to have_received(:info).with(/START Transmitting.*#{Regexp.escape(payload.to_s)}/)
      expect(logger).to have_received(:info).with(/END Transmitting.*#{Regexp.escape(payload.to_s)}/)
      expect(logger).to have_received(:info).with(/AFTER Transmitting.*#{Regexp.escape(payload.to_s)}/)
    end

    it "should nack the sent message if an error is raised" do
      exception = begin
                    raise "blow up"
                  rescue => ex
                    ex
                  end
      expect(HandyHandler).to receive(:handle!).and_raise(ex)
      expect(@receiver).not_to receive(:ack)
      expect(@receiver).to receive(:nack).with(instance_of(Fixnum))
      Pwwka::Transmitter.send_message!(payload, routing_key)
      @receiver.test_teardown # force the message to be processed and exception handled
      expect(logger).to have_received(:info).with(/START Transmitting.*#{Regexp.escape(payload.to_s)}/)
      expect(logger).to have_received(:info).with(/END Transmitting.*#{Regexp.escape(payload.to_s)}/)
      expect(logger).to have_received(:info).with(/AFTER Transmitting.*#{Regexp.escape(payload.to_s)}/)
      expect(logger).to have_received(:error).with(/Error Processing Message.*#{Regexp.escape(payload.to_s)}.*#{Regexp.escape(exception.backtrace.join(';'))}/)
    end

  end

  describe "instance methods and ::new" do

    before(:each) do
      @receiver = Pwwka::Receiver.new(queue_name, routing_key)
    end

    after(:each) do
      @receiver.test_teardown
    end

    describe "::new" do

      it "should initialize the expected attributes" do
        expect(@receiver.topic_exchange.name).to eq("topics-test")
        expect(@receiver.topic_exchange.type).to eq(:topic)
      end

    end

    describe "#topic_queue" do

      it "should return the queue with the right attributes" do
        queue = @receiver.topic_queue
        expect(queue.name).to eq(queue_name)
        expect(queue.instance_variable_get(:@bindings).count).to eq(1)
      end

    end

    describe "#ack" do

      it "should call the correct channel method" do
        delivery_tag  = 1224
        expect(@receiver.channel).to receive(:acknowledge).with(delivery_tag, false)
        @receiver.ack(delivery_tag)
      end

    end

    describe "#nack" do

      it "should call the correct channel method" do
        delivery_tag  = 1224
        expect(@receiver.channel).to receive(:nack).with(delivery_tag, false, false)
        @receiver.nack(delivery_tag)
      end

    end

    describe "#nack_requeue" do

      it "should call the correct channel method" do
        delivery_tag  = 1224
        expect(@receiver.channel).to receive(:nack).with(delivery_tag, false, true)
        @receiver.nack_requeue(delivery_tag)
      end

    end

  end

end
