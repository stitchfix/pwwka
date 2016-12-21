require 'spec_helper.rb'

describe Pwwka::Transmitter do
  let(:topic_exchange) { double("topic exchange") }
  let(:delayed_exchange) { double("delayed exchange") }
  let(:channel_connector) { instance_double(Pwwka::ChannelConnector, topic_exchange: topic_exchange, delayed_exchange: delayed_exchange) }
  let(:logger) { double(Logger) }
  let(:payload) {
    {
      foo: { bar: "blah" },
      crud: 12,
    }
  }
  let(:routing_key) { "sf.foo.bar" }


  before do
    @original_logger = Pwwka.configuration.logger
    Pwwka.configuration.logger = logger
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    allow(Pwwka::ChannelConnector).to receive(:new).and_return(channel_connector)
    allow(channel_connector).to receive(:connection_close)
    allow(topic_exchange).to receive(:publish)
    allow(delayed_exchange).to receive(:publish)
  end

  after do
    Pwwka.configuration.logger = @original_logger
  end

  subject(:transmitter) { described_class.new }

  describe ".send_message_async" do
    before do
      allow(Resque).to receive(:enqueue_in)
    end

    it "queues a Resque job" do
      delay_by_ms = 3_000
      described_class.send_message_async(payload,routing_key,delay_by_ms: delay_by_ms)
      expect(Resque).to have_received(:enqueue_in).with(delay_by_ms/1_000,Pwwka::SendMessageAsyncJob,payload,routing_key)
    end
  end

  shared_examples "it passes through to an instance" do
    context "not using delayed flag" do
      it "calls through to send_message!" do
        expect_any_instance_of(described_class).to receive(:send_message!).with(payload,routing_key)
        described_class.send(method,payload,routing_key)
      end
      it "logs after sending" do
        described_class.send(method,payload,routing_key)
        expect(logger).to have_received(:info).with(/AFTER Transmitting Message on #{routing_key} ->/)
      end
    end
    context "using delayed flag" do

      it "logs after sending" do
        allow_any_instance_of(described_class).to receive(:send_delayed_message!)
        described_class.send(method,payload,routing_key, delayed: true)
        expect(logger).to have_received(:info).with(/AFTER Transmitting Message on #{routing_key} ->/)
      end

      context "explicitly setting delay time" do
        it "calls through to send_delayed_message! using the given delay time" do
          delay_by = 1_000
          expect_any_instance_of(described_class).to receive(:send_delayed_message!).with(payload,routing_key,delay_by)
          described_class.send(method,payload,routing_key,delayed: true, delay_by: delay_by)
        end
      end
      context "using the default delay time" do
        it "calls through to send_delayed_message! using its default delay time" do
          expect_any_instance_of(described_class).to receive(:send_delayed_message!).with(payload,routing_key)
          described_class.send(method,payload,routing_key,delayed: true)
        end
      end
    end
  end

  describe ".send_message!" do
    context "no errors" do
      it_behaves_like "it passes through to an instance" do
        let(:method) { :send_message! }
      end
    end
    context "when there's an error" do
      before do
        allow_any_instance_of(described_class).to receive(:send_message!).and_raise("OH NOES")
      end
      it "logs the error" do
        begin
          described_class.send_message!(payload,routing_key)
        rescue => ex
        end
        expect(logger).to have_received(:error).with(/ERROR Transmitting Message on #{routing_key} ->/)
      end
      context "on_error: :ignore" do
        it "ignores the error" do
          expect {
            described_class.send_message!(payload,routing_key, on_error: :ignore)
          }.not_to raise_error
        end
      end
      context "on_error: :raise" do
        it "raises the error" do
          expect {
            described_class.send_message!(payload,routing_key, on_error: :raise)
          }.to raise_error(/OH NOES/)
        end
      end
      context "on_error: :resque" do
        it "queues a Resque job" do
          allow(Resque).to receive(:enqueue_in)
          described_class.send_message!(payload,routing_key, on_error: :resque)
          expect(Resque).to have_received(:enqueue_in).with(0,Pwwka::SendMessageAsyncJob,payload,routing_key)
        end
        context "when there is a problem queueing the resque job" do
          it "raises the original exception job" do
            allow(Resque).to receive(:enqueue_in).and_raise("NOPE")
            expect {
              described_class.send_message!(payload,routing_key, on_error: :resque)
            }.to raise_error(/OH NOES/)
          end
          it "logs the Resque error as a warning" do
            allow(Resque).to receive(:enqueue_in).and_raise("NOPE")
            begin
              described_class.send_message!(payload,routing_key, on_error: :resque)
            rescue => ex
            end
            expect(logger).to have_received(:warn).with(/NOPE/)
          end
        end
      end
    end
  end
  describe ".send_message_safely" do
    context "no errors" do
      it_behaves_like "it passes through to an instance" do
        let(:method) { :send_message_safely }
      end
    end
    context "when there's an error" do
      before do
        allow_any_instance_of(described_class).to receive(:send_message!).and_raise("OH NOES")
      end
      it "logs the error" do
        begin
          described_class.send_message_safely(payload,routing_key)
        rescue => ex
        end
        expect(logger).to have_received(:error).with(/ERROR Transmitting Message on #{routing_key} ->/)
      end
      it "ignores the error" do
        expect {
          described_class.send_message_safely(payload,routing_key)
        }.not_to raise_error
      end
    end
  end

  describe "#send_message!" do
    it "returns true" do
      expect(transmitter.send_message!(payload,routing_key)).to eq(true)
    end

    it "publishes the message" do
      transmitter.send_message!(payload,routing_key)
      expect(topic_exchange).to have_received(:publish).with(payload.to_json,routing_key: routing_key, persistent: true)
    end

    it "logs the start and end of the transmission" do
      transmitter.send_message!(payload,routing_key)
      expect(logger).to have_received(:info).with(/START Transmitting Message on #{routing_key} ->/)
      expect(logger).to have_received(:info).with(/END Transmitting Message on #{routing_key} ->/)
    end

    it "closes the channel connector" do
      transmitter.send_message!(payload,routing_key)
      expect(channel_connector).to have_received(:connection_close)
    end
  end

  describe "#send_delayed_message!" do
    context "delayed queue properly configured" do
      before do
        allow(channel_connector).to receive(:raise_if_delayed_not_allowed)
        allow(channel_connector).to receive(:create_delayed_queue)
      end

      it "returns true" do
        expect(transmitter.send_delayed_message!(payload,routing_key)).to eq(true)
      end

      it "creates the delayed queue" do
        transmitter.send_delayed_message!(payload,routing_key)
        expect(channel_connector).to have_received(:create_delayed_queue)
      end

      it "publishes the message to the delayed exchange" do
        delay_by = 12345
        transmitter.send_delayed_message!(payload,routing_key, delay_by)
        expect(delayed_exchange).to have_received(:publish).with(payload.to_json,routing_key: routing_key, expiration: delay_by, persistent: true)
      end

      it "logs the start and end of the transmission" do
        transmitter.send_delayed_message!(payload,routing_key)
        expect(logger).to have_received(:info).with(/START Transmitting Delayed Message on #{routing_key} ->/)
        expect(logger).to have_received(:info).with(/END Transmitting Delayed Message on #{routing_key} ->/)
      end
      it "closes the channel connector" do
        transmitter.send_delayed_message!(payload,routing_key)
        expect(channel_connector).to have_received(:connection_close)
      end
    end
    context "delayed queue not configured" do
      before do
        allow(channel_connector).to receive(:raise_if_delayed_not_allowed).and_raise("NOPE")
      end
      it "blows up" do
        expect {
          transmitter.send_delayed_message!(payload,routing_key)
        }.to raise_error(/NOPE/)
      end
    end
  end
end

