require 'spec_helper.rb'

describe Pwwka::Transmitter do

  before(:all) do
    @test_handler = Pwwka::TestHandler.new
    @test_handler.test_setup
  end

  after(:each) { @test_handler.purge_test_queue }
  after(:all) { @test_handler.test_teardown }

  let(:payload)     { { "this" => "that" } }
  let(:routing_key) { "this.that.and.theother" }
  let(:exception) { RuntimeError.new('blow up')}
  let(:logger) { double(Logger) }

  before(:each) do
    @original_logger = Pwwka.configuration.logger
    Pwwka.configuration.logger = logger
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
  end

  after(:each) do
    Pwwka.configuration.logger = @original_logger
  end

  describe "#send_message!" do

    context "happy path" do
      it "should send the correct payload" do
        success = Pwwka::Transmitter.new.send_message!(payload, routing_key)
        expect(success).to be_truthy
        received_payload = @test_handler.pop_message.payload
        expect(received_payload["this"]).to eq("that")
        expect(logger).to have_received(:info).with("START Transmitting Message on #{routing_key} -> #{payload}")
        expect(logger).to have_received(:info).with("END Transmitting Message on #{routing_key} -> #{payload}")
      end

      it "should deliver on the expected routing key" do
        success = Pwwka::Transmitter.new.send_message!(payload, routing_key)
        expect(success).to be_truthy
        delivery_info = @test_handler.pop_message.delivery_info
        expect(delivery_info.routing_key).to eq(routing_key)
      end
    end

    it "should blow up if exception raised" do
      expect_any_instance_of(Pwwka::ChannelConnector).to receive(:topic_exchange).and_raise(exception)
      expect {
        Pwwka::Transmitter.new.send_message!(payload, routing_key)
      }.to raise_error(exception)
      expect(logger).to     have_received(:info).with("START Transmitting Message on #{routing_key} -> #{payload}")
      expect(logger).not_to have_received(:info).with("END Transmitting Message on #{routing_key} -> #{payload}")
    end

  end

  describe "#send_delayed_message!" do

    context "happy path" do
      it "should send the correct payload" do
        success = Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1000)
        expect(success).to be_truthy
        expect(@test_handler.test_queue.message_count).to eq(0)
        sleep 5
        expect(@test_handler.test_queue.message_count).to eq(1)
        received_payload = @test_handler.pop_message.payload
        expect(received_payload["this"]).to eq("that")
      end

      it "should deliver on the expected routing key" do
        success = Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1)
        expect(success).to be_truthy
        sleep 1
        delivery_info = @test_handler.pop_message.delivery_info
        expect(delivery_info.routing_key).to eq(routing_key)
      end
    end

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise(exception)
      expect {
        Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1)
      }.to raise_error(exception)
    end

    context "delayed not configured" do
      it "should blow up if allow_delayed? is false" do
        expect(@test_handler.channel_connector.configuration).to receive(:allow_delayed?).at_least(:once).and_return(false)
        expect {
          Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1)
        }.to raise_error(Pwwka::ConfigurationError)
      end
    end

  end

  describe "::send_message!" do


    it "should send the correct payload" do
      Pwwka::Transmitter.send_message!(payload, routing_key)
      received_payload = @test_handler.pop_message.payload
      expect(received_payload["this"]).to eq("that")
    end

    it "should return true" do
      expect(Pwwka::Transmitter.send_message!(payload, routing_key)).to eq true
    end

    it "should ignore delay_by parameter (should it?)" do
      Pwwka::Transmitter.send_message!(payload, routing_key, delay_by: 5000)
      received_payload = @test_handler.pop_message.payload
      expect(received_payload["this"]).to eq("that")
    end

    context 'default exception policy' do
      it "should blow up if exception raised" do
        expect(Pwwka::ChannelConnector).to receive(:new).and_raise(exception)
        expect {
          Pwwka::Transmitter.send_message!(payload, routing_key)
        }.to raise_error(exception)
      end
    end

    context 'when on_error: :raise and exception raised' do
      before(:each) { expect(Pwwka::ChannelConnector).to receive(:new).and_raise(exception) }

      it "should blow up" do
        expect {
          Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :raise)
        }.to raise_error(exception)
      end
      it "should not enqueue a resque job" do
        expect(Resque).not_to receive(:enqueue_in)
        expect {
          Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :raise)
        }.to raise_error(exception)
      end
    end

    context 'when on_error: :ignore and exception raised' do
      before :each do
        expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      end
      it "should not blow up" do
        Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :ignore)
        # check nothing has been queued
        expect(@test_handler.test_queue.pop.compact.count).to eq(0)
      end
      it "should return false" do
        expect(Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :ignore)).to eql false
      end
      it "should not enqueue a resque job" do
        expect(Resque).not_to receive(:enqueue_in)
        Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :ignore)
      end
    end

    context 'when on_error: :resque and exception raised' do
      before :each do
        allow(Resque).to receive(:enqueue_in)
        expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      end
      it "should return false" do
        expect(Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :resque)).to eq false
      end

      it "should enqueue a Resque job if exception raised" do
        expect(Resque).to receive(:enqueue_in).
                              with(0, Pwwka::SendMessageAsyncJob, payload, routing_key)

        Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :resque)
        # check nothing has been queued
        expect(@test_handler.test_queue.pop.compact.count).to eq(0)
      end

      context 'and then resque fails' do
        it 'returns the original exception' do
          expect(Resque).to receive(:enqueue_in).and_raise('blow up in resque')
          expect {
            Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :resque)
          }.to raise_exception('blow up')
        end
      end
    end


    context "delayed message" do

      it "should call send_delayed_message! if requested with delay_by" do
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_delayed_message!)
                                                          .with(payload, routing_key, 2000)
        Pwwka::Transmitter.send_message!(payload, routing_key, delayed: true, delay_by: 2000)
      end

      it "should call send_delayed_message if requested without delay_by" do
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_delayed_message!)
                                                          .with(payload, routing_key)
        Pwwka::Transmitter.send_message!(payload, routing_key, delayed: true)
      end

      it "should not call send_delayed_message if not requested" do
        expect_any_instance_of(Pwwka::Transmitter).not_to receive(:send_delayed_message!)
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_message!)
        Pwwka::Transmitter.send_message_safely(payload, routing_key)
      end

      it "should enqueue a Resque job if exception raised and on_error: :resque" do
        expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")

        expect(Resque).to receive(:enqueue_in).
                              with(2, Pwwka::SendMessageAsyncJob, payload, routing_key)

        Pwwka::Transmitter.send_message!(payload, routing_key, delayed: true, delay_by: 2000, on_error: :resque)
        # check nothing has been queued
        expect(@test_handler.test_queue.pop.compact.count).to eq(0)
      end


      it "should enqueue a Resque job if exception raised and on_error: :resque without delay_by" do
        expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")

        expect(Resque).to receive(:enqueue_in).
                              with(Pwwka::Transmitter::DEFAULT_DELAY_BY_MS/1000, Pwwka::SendMessageAsyncJob, payload, routing_key)

        Pwwka::Transmitter.send_message!(payload, routing_key, delayed: true, on_error: :resque)
        # check nothing has been queued
        expect(@test_handler.test_queue.pop.compact.count).to eq(0)
      end

    end
  end


  describe '::send_message_async' do
    context 'with no delay' do
      it 'queues the message' do
        expect(Resque).to receive(:enqueue_in).
                              with(0, Pwwka::SendMessageAsyncJob, payload, routing_key)
        Pwwka::Transmitter.send_message_async(payload, routing_key)
      end
    end

    context 'with delay' do
      it 'queues the message' do
        expect(Resque).to receive(:enqueue_in).
                              with(3, Pwwka::SendMessageAsyncJob, payload, routing_key)
        Pwwka::Transmitter.send_message_async(payload, routing_key, delay_by_ms: 3000)
      end
    end
  end

  describe "::send_message_safely" do

    it "should send the correct payload" do
      Pwwka::Transmitter.send_message_safely(payload, routing_key)
      received_payload = @test_handler.pop_message.payload
      expect(received_payload["this"]).to eq("that")
    end

    it "should not blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      Pwwka::Transmitter.send_message_safely(payload, routing_key)
      # check nothing has been queued
      expect(@test_handler.test_queue.pop.compact.count).to eq(0)
    end

    context "delayed message" do

      it "should call send_delayed_message! if requested with delay_by" do
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_delayed_message!)
                                                          .with(payload, routing_key, 2000)
        Pwwka::Transmitter.send_message_safely(payload, routing_key, delayed: true, delay_by: 2000)
      end

      it "should call send_delayed_message if requested without delay_by" do
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_delayed_message!)
                                                          .with(payload, routing_key)
        Pwwka::Transmitter.send_message_safely(payload, routing_key, delayed: true)
      end

      it "should not call send_delayed_message if not requested" do
        expect_any_instance_of(Pwwka::Transmitter).not_to receive(:send_delayed_message!)
        expect_any_instance_of(Pwwka::Transmitter).to receive(:send_message!)
        Pwwka::Transmitter.send_message_safely(payload, routing_key)
      end

    end

  end

end
