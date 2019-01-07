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
    allow(Pwwka::ChannelConnector).to receive(:new).with(connection_name: "p: MyAwesomeApp").and_return(channel_connector)
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
    context "with only basic required arguments" do
      it "queues a Resque job with no extra args" do
        delay_by_ms = 3_000
        described_class.send_message_async(payload,routing_key,delay_by_ms: delay_by_ms)
        expect(Resque).to have_received(:enqueue_in).with(delay_by_ms/1_000,Pwwka::SendMessageAsyncJob,payload,routing_key)
      end
    end
    context "with everything overridden" do
      it "queues a Resque job with the various arguments" do
        delay_by_ms = 3_000
        described_class.send_message_async(
          payload,routing_key,
          delay_by_ms: delay_by_ms,
          message_id: "snowflake id that is likely a bad idea, but if you must",
          type: "Customer",
          headers: {
            "custom" => "value",
            "other_custom" => "other_value",
          }
        )
        expect(Resque).to have_received(:enqueue_in).with(
          delay_by_ms/1_000,
          Pwwka::SendMessageAsyncJob,
          payload,
          routing_key,
          message_id: "snowflake id that is likely a bad idea, but if you must",
          type: "Customer",
          headers: {
            "custom" => "value",
            "other_custom" => "other_value",
          }
        )
      end
    end
  end

  shared_examples "it passes through to an instance" do
    context "not using delayed flag" do
      it "calls through to send_message!" do
        expect_any_instance_of(described_class).to receive(:send_message!).with(payload,routing_key, type: nil, headers: nil, message_id: :auto_generate)
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
          expect_any_instance_of(described_class).to receive(:send_delayed_message!).with(payload,routing_key,delay_by, type: nil, headers: nil, message_id: :auto_generate)
          described_class.send(method,payload,routing_key,delayed: true, delay_by: delay_by)
        end
      end
      context "using the default delay time" do
        it "calls through to send_delayed_message! using its default delay time" do
          expect_any_instance_of(described_class).to receive(:send_delayed_message!).with(payload,routing_key, type: nil, headers: nil, message_id: :auto_generate)
          described_class.send(method,payload,routing_key,delayed: true)
        end
      end
    end
  end

  shared_examples "it sends standard and overridden data to the exchange" do
    it "publishes to the topic exchange" do
      expect(exchange).to have_received(:publish).with(payload.to_json, kind_of(Hash))
    end

    it "passes the routing key" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(routing_key: routing_key))
    end

    it "sets the type" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(type: "Customer"))
    end

    it "sets the headers" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(headers: { "custom" => "value", "other_custom" => "other_value" }))
    end

    it "uses the overridden message id" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(message_id: "snowflake id that is likely a bad idea, but if you must"))
    end

    it "sets the timestamp to now" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(timestamp: a_timestamp_about_now))
    end

    it "sets the app id to what's configured" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(app_id: "MyAwesomeApp"))
    end

    it "sets the content type to JSON with a version" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(content_type: "application/json; version=1"))
    end

    it "sets persistent true" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(persistent: true))
    end
  end

  shared_examples "it sends standard attributes and the payload to the exchange" do
    it "publishes to the topic exchange" do
      expect(exchange).to have_received(:publish).with(payload.to_json, kind_of(Hash))
    end

    it "passes the routing key" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(routing_key: routing_key))
    end

    it "sets a default message id" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(message_id: a_uuid))
    end

    it "sets the timestamp to now" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(timestamp: a_timestamp_about_now))
    end

    it "sets the app id to what's configured" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(app_id: "MyAwesomeApp"))
    end

    it "sets the content type to JSON with a version" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(content_type: "application/json; version=1"))
    end

    it "sets persistent true" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_including(persistent: true))
    end

    it "does not set the type" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_excluding(:type))
    end

    it "does not set headers" do
      expect(exchange).to have_received(:publish).with(
        payload.to_json,
        hash_excluding(:headers))
    end
  end

  RSpec::Matchers.define :a_uuid do |x|
    match { |actual|
      actual =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    }
  end

  RSpec::Matchers.define :a_timestamp_about_now do |x|
    match { |actual|
      (actual - Time.now.to_i).abs < 1000
    }
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
        expect(logger).to have_received(:error).with(/OH NOES/)
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

      context "on_error: :sidekiq" do
        before do
          class NullJob
          end
          Pwwka.configuration.async_job_klass = NullJob
        end

        after do
          Pwwka::configuration.async_job_klass = Pwwka::SendMessageAsyncJob
        end

        it "queues a Sidekiq job" do
          allow(NullJob).to receive(:perform_async)
          described_class.send_message!(payload, routing_key, on_error: :sidekiq)
          expect(NullJob).to have_received(:perform_async).with(
            payload,
            routing_key,
            {delay_by_ms: 0, headers: nil, message_id: :auto_generate, type: nil}
          )
        end

        context "when there is a problem queueing the Sidekiq job" do
          it "raises the original exception job" do
            allow(NullJob).to receive(:perform_async).and_raise("NOPE")
            expect {
              described_class.send_message!(payload, routing_key, on_error: :sidekiq)
            }.to raise_error(/OH NOES/)
          end

          it "logs the Sidekiq error as a warning" do
            allow(NullJob).to receive(:perform_async).and_raise("NOPE")
            begin
              described_class.send_message!(payload,routing_key, on_error: :sidekiq)
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
        expect(logger).to have_received(:error).with(/OH NOES/)
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

    it "logs the start and end of the transmission" do
      transmitter.send_message!(payload,routing_key)
      expect(logger).to have_received(:info).with(/START Transmitting Message on id\[[\w\-\d]+\] #{routing_key} ->/)
      expect(logger).to have_received(:info).with(/END Transmitting Message on id\[[\w\-\d]+\] #{routing_key} ->/)
    end

    it "closes the channel connector" do
      transmitter.send_message!(payload,routing_key)
      expect(channel_connector).to have_received(:connection_close)
    end

    context 'when an error is raised' do
      subject { transmitter.send_message!(payload,routing_key) }
      let(:error) { 'oh no' }

      before do
        allow(topic_exchange).to receive(:publish).and_raise(error)
      end

      it 'should raise the error' do
        expect { subject } .to raise_error(error)
      end

      it 'should close the channel connector' do
        begin; subject; rescue; end
        expect(channel_connector).to have_received(:connection_close)
      end
    end

    context "with only basic required arguments" do
      before do
        transmitter.send_message!(payload,routing_key)
      end

      it_behaves_like "it sends standard attributes and the payload to the exchange" do
        let(:exchange) { topic_exchange }
      end
    end

    context "with everything overridden" do
      before do
        transmitter.send_message!(
          payload,
          routing_key,
          message_id: "snowflake id that is likely a bad idea, but if you must",
          type: "Customer",
          headers: {
            "custom" => "value",
            "other_custom" => "other_value",
          }
        )
      end

      it_behaves_like "it sends standard and overridden data to the exchange" do
        let(:exchange) { topic_exchange }
      end
    end
  end

  describe "#send_delayed_message!" do
    context "delayed queue properly configured" do
      before do
        allow(channel_connector).to receive(:raise_if_delayed_not_allowed)
        allow(channel_connector).to receive(:create_delayed_queue)
      end

      it "creates the delayed queue" do
        transmitter.send_delayed_message!(payload,routing_key)
        expect(channel_connector).to have_received(:create_delayed_queue)
      end

      context 'when an error is raised' do
        subject { transmitter.send_delayed_message!(payload,routing_key) }
        let(:error) { 'oh no' }

        before do
          allow(delayed_exchange).to receive(:publish).and_raise(error)
        end

        it 'should raise the error' do
          expect { subject } .to raise_error(error)
        end

        it 'should close the channel connector' do
          begin; subject; rescue; end
          expect(channel_connector).to have_received(:connection_close)
        end
      end

      context "with only basic required arguments" do
        before do
          transmitter.send_delayed_message!(payload,routing_key,5_000)
        end

        it_behaves_like "it sends standard attributes and the payload to the exchange" do
          let(:exchange) { delayed_exchange }
        end

        it "passes an expiration value" do
          expect(delayed_exchange).to have_received(:publish).with(
            payload.to_json,
            hash_including(expiration: 5_000))
        end
      end

      context "with everything overridden" do
        before do
          transmitter.send_delayed_message!(
            payload,
            routing_key,
            message_id: "snowflake id that is likely a bad idea, but if you must",
            type: "Customer",
            headers: {
              "custom" => "value",
              "other_custom" => "other_value",
            }
          )
        end

        it_behaves_like "it sends standard and overridden data to the exchange" do
          let(:exchange) { delayed_exchange }
        end
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

