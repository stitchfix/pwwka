require 'spec_helper.rb'

# Most of this class is just interacting with Rabbit so it's covered
# by the integration tests.
describe Pwwka::ChannelConnector do
  let(:bunny_session) { instance_double(Bunny::Session) }
  subject(:channel_connector) { described_class.new }

  describe "initialize" do
    let(:bunny_channel) { instance_double(Bunny::Channel) }

    before do
      allow(Bunny).to receive(:new).and_return(bunny_session)
      allow(bunny_session).to receive(:start)
      allow(bunny_session).to receive(:create_channel).and_return(bunny_channel)
    end

    it "sets a prefetch value if configured to do so" do
      allow(Pwwka.configuration).to receive(:prefetch).and_return(10)
      expect(bunny_channel).to receive(:prefetch).with(10)

      channel_connector
    end
  end

  describe "raise_if_delayed_not_allowed" do
    before do
      allow(Bunny).to receive(:new).and_return(bunny_session)
      allow(bunny_session).to receive(:start)
      allow(bunny_session).to receive(:create_channel)
      @default_allow_delayed = Pwwka.configuration.options[:allow_delayed]
    end

    after do
      Pwwka.configuration.options[:allow_delayed] = @default_allow_delayed
    end

    context "delayed is configured" do
      it "does not blow up" do
        Pwwka.configuration.options[:allow_delayed] = true
        expect {
          channel_connector.raise_if_delayed_not_allowed
        }.not_to raise_error
      end
    end
    context "delayed is not configured" do
      it "blows up" do
        Pwwka.configuration.options[:allow_delayed] = false
        expect {
          channel_connector.raise_if_delayed_not_allowed
        }.to raise_error(Pwwka::ConfigurationError)
      end
    end
  end

end
