require 'spec_helper.rb'

describe Pwwka::Receiver do
  describe "#new" do
    let(:handler_klass) { double('HandlerKlass') }
    let(:channel_connector) { instance_double(Pwwka::ChannelConnector, topic_exchange: topic_exchange, channel: channel)}
    let(:topic_exchange) { double("topic exchange") }
    let(:channel) { double('channel', queue: queue) }
    let(:queue) { double('queue') }
    let(:queue_name) { 'test_queue_name' }

    subject {
      described_class.subscribe(
        handler_klass,
        queue_name
      )
    }

    before do
      allow(Pwwka::ChannelConnector).to receive(:new).and_return(channel_connector)
      allow(handler_klass).to receive(:handle!)
      allow(channel_connector).to receive(:connection_close)
      allow(queue).to receive(:bind)
      allow(queue).to receive(:subscribe).and_yield({}, {}, '{}')
    end

    it 'sets the correct connection_name' do
      subject
      expect(Pwwka::ChannelConnector).to have_received(:new).with(prefetch: nil, connection_name: "c: MyAwesomeApp my_awesome_process")
    end

    it 'logs on interrupt' do
      allow(handler_klass).to receive(:handle!).and_raise(Interrupt)
      allow(described_class).to receive(:info)
      begin; subject; rescue; end
      expect(described_class).to have_received(:info).with(/Interrupting queue #{queue_name}/)
    end
  end
end
