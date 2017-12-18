require 'spec_helper.rb'
require 'resqutils/spec/resque_helpers'
require 'resqutils/spec/resque_matchers'
require 'pwwka/queue_resque_job_handler'

require_relative "support/integration_test_setup"
require_relative "support/logging_receiver"
require_relative "support/integration_test_helpers"

describe "sending and receiving messages", :integration do
  include IntegrationTestHelpers
  include Resqutils::Spec::ResqueHelpers

  before do
    ENV["JOB_KLASS"] = MyTestJob.name
    ENV["PWWKA_QUEUE_EXTENDED_INFO"] = "true"
    @testing_setup = IntegrationTestSetup.new
    [

      [AllReceiver                  , "all_receiver_pwwkatesting"             , "#"]                 ,
      [FooReceiver                  , "foo_receiver_pwwkatesting"             , "pwwka.testing.foo"] ,
      [MultiRoutingReceived         , "multi_routing_receiver_pwwkatesting"   , "pwwka.testing.bar,pwwka.testing.foo"] ,
      [OtherFooReceiver             , "other_foo_receiver_pwwkatesting"       , "pwwka.testing.foo"] ,
      [Pwwka::QueueResqueJobHandler , "queue_resque_job_handler_pwwkatesting" , "#" ]                ,

    ].each do |(klass, queue_name, routing_key)|
      @testing_setup.make_queue_and_setup_receiver(klass,queue_name,routing_key)
    end
    AllReceiver.reset!
    FooReceiver.reset!
    MultiRoutingReceived.reset!
    OtherFooReceiver.reset!
    clear_queue(:delayed)
    clear_queue(MyTestJob)
  end

  after do
    @testing_setup.kill_threads_and_clear_queues
    ENV.delete("JOB_KLASS")
    ENV.delete("PWWKA_QUEUE_EXTENDED_INFO")
  end

  context "routing" do
    it "can send a message that gets routed to all receivers" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(AllReceiver.messages_received.size).to eq(1)
      expect(FooReceiver.messages_received.size).to eq(1)
      expect(MultiRoutingReceived.messages_received.size).to eq(1)
      expect(OtherFooReceiver.messages_received.size).to eq(1)
      @testing_setup.queues.each do |queue|
        expect(queue.message_count).to eq(0)
      end
    end
    it "can send a message that is only delivered to some  handlers based on routing key" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.bar")
      allow_receivers_to_process_queues

      expect(AllReceiver.messages_received.size).to eq(1)
      expect(FooReceiver.messages_received.size).to eq(0)
      expect(MultiRoutingReceived.messages_received.size).to eq(1)
      expect(OtherFooReceiver.messages_received.size).to eq(0)
      @testing_setup.queues.each do |queue|
        expect(queue.message_count).to eq(0)
      end
    end
  end

  context "metadata" do
    it "can access standard metadata" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(AllReceiver.metadata[0].message_id).not_to be_nil
      expect(AllReceiver.metadata[0].timestamp).to be_within(2.minutes).of(Time.now)
      expect(AllReceiver.metadata[0].content_type).to eq("application/json; version=1")
      expect(AllReceiver.metadata[0].app_id).to eq("MyAwesomeApp")
    end

    it "can access standard metadata on delayed jobs" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo",
                                       delayed: true,
                                       delay_by: 100)
      allow_receivers_to_process_queues(200)

      expect(AllReceiver.metadata[0].message_id).not_to be_nil
      expect(AllReceiver.metadata[0].timestamp).to be_within(2.minutes).of(Time.now)
      expect(AllReceiver.metadata[0].content_type).to eq("application/json; version=1")
      expect(AllReceiver.metadata[0].app_id).to eq("MyAwesomeApp")
    end

    it "can access explicitly-provided metadata" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo",
                                       type: "Customer",
                                       headers: {
                                         foo: "bar",
                                         blah: 42,
                                       })
      allow_receivers_to_process_queues

      expect(AllReceiver.metadata[0].message_id).not_to be_nil
      expect(AllReceiver.metadata[0].timestamp).to be_within(2.minutes).of(Time.now)
      expect(AllReceiver.metadata[0].content_type).to eq("application/json; version=1")
      expect(AllReceiver.metadata[0].app_id).to eq("MyAwesomeApp")
      expect(AllReceiver.metadata[0].type).to eq("Customer")
      expect(AllReceiver.metadata[0].headers["foo"]).to eq("bar")
      expect(AllReceiver.metadata[0].headers["blah"]).to eq(42)
    end

    it "can access explicitly-provided metadata on delayed jobs" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo",
                                       type: "Customer",
                                       headers: {
                                         foo: "bar",
                                         blah: 42,
                                       },
                                       delayed: true,
                                       delay_by: 100)
      allow_receivers_to_process_queues(200)

      expect(AllReceiver.metadata[0].message_id).not_to be_nil
      expect(AllReceiver.metadata[0].timestamp).to be_within(2.minutes).of(Time.now)
      expect(AllReceiver.metadata[0].content_type).to eq("application/json; version=1")
      expect(AllReceiver.metadata[0].type).to eq("Customer")
      expect(AllReceiver.metadata[0].app_id).to eq("MyAwesomeApp")
      expect(AllReceiver.metadata[0].headers["foo"]).to eq("bar")
      expect(AllReceiver.metadata[0].headers["blah"]).to eq(42)
    end
  end

  context "sending messages from a background job" do
    it "can queue a job to send a message from a Resque job" do
      Pwwka::Transmitter.send_message_async({ sample: "payload", has: { deeply: true, nested: 4 }},
                                            "pwwka.testing.bar")

      allow_receivers_to_process_queues # not expecting anything to be processed

      expect(AllReceiver.messages_received.size).to eq(0)

      process_resque_job(Pwwka::SendMessageAsyncJob,:delayed)

      allow_receivers_to_process_queues

      expect(AllReceiver.messages_received.size).to eq(1)
    end

    it "can queue a job with optional arguments to send a message from a Resque job" do
      Pwwka::Transmitter.send_message_async(
        { sample: "payload", has: { deeply: true, nested: 4 }},
        "pwwka.testing.bar",
        message_id: "setting this is a bad idea, but you can do it",
        headers: {
          "FOO" => "bar"
        },
        type: "Customer"
      )

      allow_receivers_to_process_queues # not expecting anything to be processed

      expect(AllReceiver.messages_received.size).to eq(0)

      process_resque_job(Pwwka::SendMessageAsyncJob,:delayed)

      allow_receivers_to_process_queues

      expect(AllReceiver.messages_received.size).to eq(1)
      expect(AllReceiver.metadata[0].message_id).to eq("setting this is a bad idea, but you can do it")
      expect(AllReceiver.metadata[0].timestamp).to be_within(2.minutes).of(Time.now)
      expect(AllReceiver.metadata[0].content_type).to eq("application/json; version=1")
      expect(AllReceiver.metadata[0].type).to eq("Customer")
      expect(AllReceiver.metadata[0].app_id).to eq("MyAwesomeApp")
      expect(AllReceiver.metadata[0].headers["FOO"]).to eq("bar")
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
  end

  it "can send a message delayed" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo",
                                      delayed: true,
                                      delay_by: 5_000)
    allow_receivers_to_process_queues(1_000)

    expect(AllReceiver.messages_received.size).to eq(0)
    expect(FooReceiver.messages_received.size).to eq(0)
    expect(MultiRoutingReceived.messages_received.size).to eq(0)
    expect(OtherFooReceiver.messages_received.size).to eq(0)

    allow_receivers_to_process_queues(5_000)
    expect(AllReceiver.messages_received.size).to eq(1)
    expect(FooReceiver.messages_received.size).to eq(1)
    expect(MultiRoutingReceived.messages_received.size).to eq(1)
    expect(OtherFooReceiver.messages_received.size).to eq(1)
  end

  it "can receive a message on a handler that just queues background jobs" do
    payload = { sample: "payload", has: { deeply: true, nested: 4 }}
    Pwwka::Transmitter.send_message!(payload, "foo.bar")

    allow_receivers_to_process_queues

    job = Resque.pop(:test_queue)
    aggregate_failures "job paylod" do
      expect(job["class"]).to eq(MyTestJob.name)
      expect(job["args"][0]).to eq({ "sample" => "payload", "has" => { "deeply" => true, "nested" => 4 }})
      expect(job["args"][1]).to eq("foo.bar")

      # Expect a few things from the metadata for sanity
      expect(job["args"][2].keys).to include("content_type")
      expect(job["args"][2].keys).to include("message_id")
      expect(job["args"][2].keys).to include("timestamp")
    end
  end

  class MyTestJob
    @queue = "test_queue"

    def self.perform(payload,routing_key,properties)
    end
  end


  class AllReceiver < LoggingReceiver
  end
  class FooReceiver < AllReceiver
  end
  class OtherFooReceiver < AllReceiver
  end
  class MultiRoutingReceived < AllReceiver
  end
end
