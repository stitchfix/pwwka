require 'spec_helper.rb'

describe Pwwka::Receiver do
  describe "#new" do 
    let(:channel_connector) { double(Pwwka::ChannelConnector)}

    before do
      allow(Pwwka::ChannelConnector).to receive(:new).with(prefetch: nil, connection_name: "c: test_queue_name").and_return(channel_connector)
      allow(channel_connector).to receive(:channel)
      allow(channel_connector).to receive(:topic_exchange)
    end

    it "should set the connection_name" do
      Pwwka::Receiver.new("test_queue_name", "test.routing.key")
    end
  end
end
