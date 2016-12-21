require 'spec_helper.rb'
require_relative "support/integration_test_setup"
require_relative "support/logging_receiver"
require_relative "support/integration_test_helpers"

describe "receivers being interrupted", :integration do
  include IntegrationTestHelpers

  before do
    @testing_setup = IntegrationTestSetup.new
    setup_receivers
  end

  before :each do
    WellBehavedReceiver.reset!
  end

  after do
    @testing_setup.kill_threads_and_clear_queues
  end

  it "an error in one receiver doesn't prevent others from getting messages" do
    Pwwka::Transmitter.send_message!({ sample: "payload", has: { deeply: true, nested: 4 }},
                                     "pwwka.testing.foo")
    allow_receivers_to_process_queues

    expect(WellBehavedReceiver.messages_received.size).to eq(1)
    expect(@testing_setup.threads[WellBehavedReceiver].alive?).to eq(true)
    expect(@testing_setup.threads[InterruptingReceiver].alive?).to eq(false)
  end

  def setup_receivers
    [
      [InterruptingReceiver, "interrupting_receiver_pwwkatesting"],
      [WellBehavedReceiver, "well_behaved_receiver_pwwkatesting"],
    ].each do |(klass, queue_name)|
      @testing_setup.make_queue_and_setup_receiver(klass,queue_name,"#")
    end
  end
  class InterruptingReceiver
    def self.handle!(delivery_info,properties,payload)
      raise Interrupt,'simulated interrupt would realy be a signal'
    end
  end
  class WellBehavedReceiver < LoggingReceiver
  end
end
