require 'spec_helper.rb'

describe Pwwka::Transmitter do

  before(:all) do
    @test_handler = Pwwka::TestHandler.new
    @test_handler.test_setup
  end

  after(:each) { @test_handler.purge_test_queue }
  after(:all) { @test_handler.test_teardown }

  let(:payload)     { Hash[:this, "that"] }
  let(:routing_key) { "this.that.and.theother" }

  describe "#send_message!" do

    context "happy path" do
      it "should send the correct payload" do
        success = Pwwka::Transmitter.new.send_message!(payload, routing_key)
        expect(success).to be_truthy
        received_payload = @test_handler.pop_message.payload
        expect(received_payload["this"]).to eq("that")
      end

      it "should delivery on the expected routing key" do
        success = Pwwka::Transmitter.new.send_message!(payload, routing_key)
        expect(success).to be_truthy
        delivery_info = @test_handler.pop_message.delivery_info
        expect(delivery_info.routing_key).to eq(routing_key)
      end
    end

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      expect {
        Pwwka::Transmitter.new.send_message!(payload, routing_key)
      }.to raise_error
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

      it "should delivery on the expected routing key" do
        success = Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1)
        expect(success).to be_truthy
        sleep 1
        delivery_info = @test_handler.pop_message.delivery_info
        expect(delivery_info.routing_key).to eq(routing_key)
      end
    end

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      expect {
        Pwwka::Transmitter.new.send_delayed_message!(payload, routing_key, 1)
      }.to raise_error
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

    it "should blow up if exception raised" do
      expect(Pwwka::ChannelConnector).to receive(:new).and_raise("blow up")
      expect{
        Pwwka::Transmitter.send_message!(payload, routing_key)
      }.to raise_error
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
