require 'spec_helper.rb'
require_relative "support/integration_test_setup"
require_relative "support/logging_receiver"
require_relative "support/integration_test_helpers"

class EvilPayload
  def to_json
    "This is not JSON by any stretch"
  end
end
describe "receivers with unhandled errors", :integration do
  include IntegrationTestHelpers

  before do
    @testing_setup = IntegrationTestSetup.new
    Pwwka.configuration.instance_variable_set("@error_handling_chain",nil)
    Pwwka.configure do |c|
      c.requeue_on_error = false
      c.keep_alive_on_handler_klass_exceptions = false
    end
  end

  after do
    @testing_setup.kill_threads_and_clear_queues
  end

  context "default configuration to crash on errors" do
    before do
      setup_receivers
      WellBehavedReceiver.reset!
      ExceptionThrowingReceiver.reset!
      IntermittentErrorReceiver.reset!
      ExceptionThrowingReceiverWithErrorHook.reset!
    end

    it "an error in one receiver doesn't prevent others from getting messages" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(WellBehavedReceiver.messages_received.size).to eq(1)
      expect(ExceptionThrowingReceiver.messages_received.size).to eq(1)
    end
    it "crashes the receiver that received an error" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(@testing_setup.threads[ExceptionThrowingReceiver].alive?).to eq(false)
    end

    it "does not crash the receiver on a borked payload, but doesn't call handlers either" do
      Pwwka.configure do |c|
        c.requeue_on_error = true
      end
      Pwwka::Transmitter.send_message!(EvilPayload.new,
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(@testing_setup.threads[ExceptionThrowingReceiver].alive?).to eq(true)
      expect(@testing_setup.threads[WellBehavedReceiver].alive?).to eq(true)
      expect(@testing_setup.threads[IntermittentErrorReceiver].alive?).to eq(true)
      expect(WellBehavedReceiver.messages_received.size).to eq(0)
      expect(ExceptionThrowingReceiver.messages_received.size).to eq(0)
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
  end

  context "configured not to crash on error" do
    before do
      setup_receivers
      WellBehavedReceiver.reset!
      ExceptionThrowingReceiver.reset!
      IntermittentErrorReceiver.reset!
      ExceptionThrowingReceiverWithErrorHook.reset!
    end
    it "does not crash the receiver that received an error" do
      Pwwka.configure do |c|
        c.keep_alive_on_handler_klass_exceptions = true
      end
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(@testing_setup.threads[ExceptionThrowingReceiver].alive?).to eq(true)
    end
  end

  context "configured to requeue failed messages" do
    before do
      setup_receivers
      WellBehavedReceiver.reset!
      ExceptionThrowingReceiver.reset!
      IntermittentErrorReceiver.reset!
      ExceptionThrowingReceiverWithErrorHook.reset!
    end
    it "requeues the message exactly once" do
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
  end

  context "handler with a custom error handler that ignores the exception" do
    before do
      setup_receivers(ExceptionThrowingReceiverWithErrorHook)
      WellBehavedReceiver.reset!
      ExceptionThrowingReceiver.reset!
      IntermittentErrorReceiver.reset!
      ExceptionThrowingReceiverWithErrorHook.reset!
    end

    it "does not crash the receiver" do
      Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                       "pwwka.testing.foo")
      allow_receivers_to_process_queues

      expect(ExceptionThrowingReceiverWithErrorHook.messages_received.size).to eq(1)
      expect(@testing_setup.threads[ExceptionThrowingReceiverWithErrorHook].alive?).to eq(true)
    end
  end

  def setup_receivers(exception_throwing_receiver_klass=ExceptionThrowingReceiver)
    [
      [exception_throwing_receiver_klass, "exception_throwing_receiver_pwwkatesting"],
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
  class NoOpHandler < Pwwka::ErrorHandlers::BaseErrorHandler
    def initialize(*)
    end
    def handle_error(receiver,queue_name,payload,delivery_info,exception)
      receiver.nack(delivery_info.delivery_tag)
      abort_chain
    end
  end
  class ExceptionThrowingReceiverWithErrorHook < LoggingReceiver
    def self.error_handler
      NoOpHandler
    end

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
