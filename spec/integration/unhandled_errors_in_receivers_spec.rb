require 'spec_helper.rb'
require_relative "support/integration_test_setup"
require_relative "support/logging_receiver"
require_relative "support/integration_test_helpers"

describe "receivers with unhandled errors", :integration do
  include IntegrationTestHelpers

  before do
    @testing_setup = IntegrationTestSetup.new
    setup_receivers
    Pwwka.configure do |c|
      c.requeue_on_error = false
      c.keep_alive_on_handler_klass_exceptions = false
    end
  end

  before :each do
    WellBehavedReceiver.reset!
    ExceptionThrowingReceiver.reset!
    IntermittentErrorReceiver.reset!
  end

  after do
    @testing_setup.kill_threads_and_clear_queues
  end

  it "an error in one receiver doesn't prevent others from getting messages" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(WellBehavedReceiver.messages_received.size).to eq(1)
    expect(ExceptionThrowingReceiver.messages_received.size).to eq(1)
  end

  it "when configured to requeue failed messages, the message is requeued exactly once" do
    Pwwka.configure do |c|
      c.requeue_on_error = true
      c.keep_alive_on_handler_klass_exceptions = true # only so we can check that the requeued message got sent; otherwise the receiver crashes and we can't test that
    end
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(WellBehavedReceiver.messages_received.size).to eq(1)
    expect(ExceptionThrowingReceiver.messages_received.size).to eq(2)
    expect(ExceptionThrowingReceiver.messages_received[1][0].redelivered).to eq(true)
    expect(ExceptionThrowingReceiver.messages_received[1][2]).to eq(ExceptionThrowingReceiver.messages_received[0][2])
  end

  it "crashes the receiver that received an error" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(@testing_setup.threads[ExceptionThrowingReceiver].alive?).to eq(false)
  end

  it "does not crash the receiver that received an error when we configure it not to" do
    Pwwka.configure do |c|
      c.keep_alive_on_handler_klass_exceptions = true
    end
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(@testing_setup.threads[ExceptionThrowingReceiver].alive?).to eq(true)
  end

  it "does not crash the receiver that successfully processed a message" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(@testing_setup.threads[WellBehavedReceiver].alive?).to  eq(true)
  end

  it "crashes the receiver if it gets a failure that we retry" do
    Pwwka.configure do |c|
      c.requeue_on_error = true
    end
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(@testing_setup.threads[IntermittentErrorReceiver].alive?).to eq(false)
  end

  def setup_receivers
    [
      [ExceptionThrowingReceiver, "exception_throwing_receiver_pwwkatesting"],
      [WellBehavedReceiver, "well_behaved_receiver_pwwkatesting"],
      [IntermittentErrorReceiver, "intermittent_error_receiver_pwwkatesting"],
    ].each do |(klass, queue_name)|
      @testing_setup.make_queue_and_setup_receiver(klass,queue_name,"#")
    end
  end
  class ExceptionThrowingReceiver < LoggingReceiver
    def self.handle!(delivery_info,properties,payload)
      super(delivery_info,properties,payload)
      raise "OH NOES!"
    end
  end
  class IntermittentErrorReceiver < LoggingReceiver
    def self.handle!(delivery_info,properties,payload)
      super(delivery_info,properties,payload)
      unless delivery_info.redelivered
        raise "OH NOES!"
      end
    end
  end
  class WellBehavedReceiver < LoggingReceiver
  end
end
