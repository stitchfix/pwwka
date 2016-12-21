require 'spec_helper.rb'
require_relative "support/integration_test_setup"
require_relative "support/integration_test_helpers"

describe "test handler for integration tests", :integration do
  include IntegrationTestHelpers

  subject(:test_handler) { Pwwka::TestHandler.new }
  before do
    test_handler.purge_test_queue
    test_handler.test_setup
    @testing_setup = IntegrationTestSetup.new
    @logger = Pwwka.configuration.logger
  end

  after do
    test_handler.test_teardown
    @testing_setup.kill_threads_and_clear_queues
    Pwwka.configuration.logger = @logger
  end

  it "allows introspecting messages that were sent" do
    first_payload = { sample: "payload", has: { deeply: true, nested: 4 }}
    second_payload = { other: :payload }

    Pwwka::Transmitter.send_message!(first_payload,  "pwwka.testing.foo")
    Pwwka::Transmitter.send_message!(second_payload, "pwwka.testing.bar")

    first_message = test_handler.pop_message
    expect(first_message.delivery_info).not_to be_nil
    expect(first_message.properties).not_to be_nil
    expect(first_message.payload).to eq(JSON.parse(first_payload.to_json))

    second_message = test_handler.pop_message
    expect(second_message.delivery_info).not_to be_nil
    expect(second_message.properties).not_to be_nil
    expect(second_message.payload).to eq(JSON.parse(second_payload.to_json))

  end

  it "get_topic_message_payload_for_tests" do
    first_payload = { sample: "payload", has: { deeply: true, nested: 4 }}

    stringio = StringIO.new
    Pwwka.configuration.logger = Logger.new(stringio)
    Pwwka::Transmitter.send_message!(first_payload,  "pwwka.testing.foo")

    payload = test_handler.get_topic_message_payload_for_tests
    expect(payload).to eq(JSON.parse(first_payload.to_json))
    expect(stringio.string).to match(/get_topic_message_payload_for_tests is deprecated/)
  end

  it "get_topic_message_properties_for_tests" do
    first_payload = { sample: "payload", has: { deeply: true, nested: 4 }}

    stringio = StringIO.new
    Pwwka.configuration.logger = Logger.new(stringio)
    Pwwka::Transmitter.send_message!(first_payload,  "pwwka.testing.foo")

    properties = test_handler.get_topic_message_properties_for_tests
    expect(properties).to_not be_nil
    expect(stringio.string).to match(/get_topic_message_properties_for_tests is deprecated/)
  end

  it "get_topic_message_delivery_info_for_tests" do
    first_payload = { sample: "payload", has: { deeply: true, nested: 4 }}

    stringio = StringIO.new
    Pwwka.configuration.logger = Logger.new(stringio)
    Pwwka::Transmitter.send_message!(first_payload,  "pwwka.testing.foo")

    delivery_info = test_handler.get_topic_message_delivery_info_for_tests
    expect(delivery_info).to_not be_nil
    expect(stringio.string).to match(/get_topic_message_delivery_info_for_tests is deprecated/)
  end


end
