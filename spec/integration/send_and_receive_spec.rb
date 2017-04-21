require 'spec_helper.rb'
require 'resqutils/spec/resque_helpers'

require_relative "support/integration_test_setup"
require_relative "support/logging_receiver"
require_relative "support/integration_test_helpers"

describe "sending and receiving messages", :integration do
  include IntegrationTestHelpers
  include Resqutils::Spec::ResqueHelpers

  before do
    @testing_setup = IntegrationTestSetup.new
    [
      [AllReceiver      , "all_receiver_pwwkatesting"       , "#"]                 ,
      [FooReceiver      , "foo_receiver_pwwkatesting"       , "pwwka.testing.foo"] ,
      [OtherFooReceiver , "other_foo_receiver_pwwkatesting" , "pwwka.testing.foo"] ,
    ].each do |(klass, queue_name, routing_key)|
      @testing_setup.make_queue_and_setup_receiver(klass,queue_name,routing_key)
    end
  end

  before :each do
    AllReceiver.reset!
    FooReceiver.reset!
    OtherFooReceiver.reset!
    clear_queue(:delayed)
  end

  after do
    @testing_setup.kill_threads_and_clear_queues
  end

  it "can send a message that gets routed to all receivers" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(AllReceiver.messages_received.size).to eq(1)
    expect(FooReceiver.messages_received.size).to eq(1)
    expect(OtherFooReceiver.messages_received.size).to eq(1)
    @testing_setup.queues.each do |queue|
      expect(queue.message_count).to eq(0)
    end
  end

  it "can send a message delayed" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo",
                                      delayed: true,
                                      delay_by: 5_000)
    allow_receivers_to_process_queues(1_000)

    expect(AllReceiver.messages_received.size).to eq(0)
    expect(FooReceiver.messages_received.size).to eq(0)
    expect(OtherFooReceiver.messages_received.size).to eq(0)

    allow_receivers_to_process_queues(5_000)
    expect(AllReceiver.messages_received.size).to eq(1)
    expect(FooReceiver.messages_received.size).to eq(1)
    expect(OtherFooReceiver.messages_received.size).to eq(1)
  end

  it "can send a message that is only delivered to some  handlers based on routing key" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.bar")
    allow_receivers_to_process_queues

    expect(AllReceiver.messages_received.size).to eq(1)
    expect(FooReceiver.messages_received.size).to eq(0)
    expect(OtherFooReceiver.messages_received.size).to eq(0)
    @testing_setup.queues.each do |queue|
      expect(queue.message_count).to eq(0)
    end
  end

  it "can queue a job to send a message from a Resque job" do
    Pwwka::Transmitter.send_message_async({ sample: "payload", has: { deeply: true, nested: 4 }},
                                          "pwwka.testing.bar")

    allow_receivers_to_process_queues # not expecting anything to be processed

    expect(AllReceiver.messages_received.size).to eq(0)

    process_resque_job(Pwwka::SendMessageAsyncJob,:delayed)

    allow_receivers_to_process_queues

    expect(AllReceiver.messages_received.size).to eq(1)
  end

  it "can queue a job to send a message to a specified Resque job queue" do
    async_job_klass = double(:async_job_klass)
    configuration = Pwwka::Configuration.new
    configuration.async_job_klass = async_job_klass

    allow(Pwwka).to receive(:configuration).and_return(configuration)

    allow(Resque).to receive(:enqueue_in)

    Pwwka::Transmitter.send_message_async({ sample: "payload", has: { deeply: true, nested: 4 }},
                                          "pwwka.testing.bar")

    expect(Resque).to have_received(:enqueue_in).with(anything, async_job_klass, anything, anything)
  end

  class AllReceiver < LoggingReceiver
  end
  class FooReceiver < AllReceiver
  end
  class OtherFooReceiver < AllReceiver
  end
end
