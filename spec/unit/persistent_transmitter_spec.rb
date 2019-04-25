require 'spec_helper.rb'

describe Pwwka::PersistentTransmitter do
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
    allow(Pwwka::ChannelConnector).to receive(:new).with(connection_name: "p: MyAwesomeApp my_awesome_process").and_return(channel_connector)
    allow(channel_connector).to receive(:connection_close)
    allow(topic_exchange).to receive(:publish)
    allow(delayed_exchange).to receive(:publish)
  end

  after do
    Pwwka.configuration.logger = @original_logger
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


    context "no new instance creation" do
      it "doesn't allow creation of new instances unless inside the batch method" do
        expect{ Pwwka::PersistentTransmitter.new }.to raise_error
      end
    end

    describe "#batch" do
      context "Logging" do
          it "logs the start and end of the transmission" do
            described_class.batch do |transmitter|
              transmitter.send_message!(payload,routing_key)
            end
            expect(logger).to have_received(:info).with(/START Transmitting Message on id\[[\w\-\d]+\] #{routing_key} ->/)
            expect(logger).to have_received(:info).with(/END Transmitting Message on id\[[\w\-\d]+\] #{routing_key} ->/)
          end
      end

      it "closes the channel connector" do
        described_class.batch do |transmitter|
          transmitter.send_message!(payload,routing_key)
        end      
        expect(channel_connector).to have_received(:connection_close)
      end

      it "only uses one connection" do
        described_class.batch do |transmitter|
          10.times do
            transmitter.send_message!(payload,routing_key)
          end
        end  
        expect(channel_connector).to have_received(:connection_close).once
      end
    end

    context 'when an error is raised' do

      let(:error) { 'oh no' }

      before do
        allow(topic_exchange).to receive(:publish).and_raise(error)
      end

      it 'should raise the error and still close the channel_connector' do     
        expect { described_class.batch do |transmitter|
                    transmitter.send_message!(payload,routing_key)
                 end } .to raise_error(error)
        expect(channel_connector).to have_received(:connection_close)
      end
    end
  
   context "with everything overridden" do
      before do
        described_class.batch do |transmitter|
            transmitter.send_message!(
              payload,
              routing_key,
              message_id: "snowflake id that is likely a bad idea, but if you must",
              type: "Customer",
              headers: {
                "custom" => "value",
                "other_custom" => "other_value",
              })
        end
      end

      it_behaves_like "it sends standard and overridden data to the exchange" do
        let(:exchange) { topic_exchange }
      end
    end

end
