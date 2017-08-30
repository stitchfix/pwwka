require 'spec_helper'
require 'pwwka/queue_resque_job_handler'

class MyLegacyTestJob
  def self.perform(payload)
  end
end

class MyNewTestJob
  def self.perform(payload, routing_key, properties)
  end
end

describe Pwwka::QueueResqueJobHandler do

  describe "::handle!" do
    let(:job_class) { MyLegacyTestJob }
    let(:routing_key) { "foo.bar.blah" }
    let(:delivery_info) { double("delivery info", routing_key: routing_key) }
    let(:properties_hash) {
      {
        "app_id" => "myapp",
        "timestamp" => "2015-12-12 13:22:99",
        "message_id" => "66",
      }
    }
    let(:properties) { Bunny::MessageProperties.new(properties_hash) }
    let(:payload) {
      {
        "this" => "is",
        "some" => true,
        "payload" => 99,
      }
    }

    before do
      allow(Resque).to receive(:enqueue)
      ENV["JOB_KLASS"] = MyLegacyTestJob.name
    end

    context "when not asking for more information explicitly" do
      it "should queue a resque job using JOB_KLASS and the payload" do
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyLegacyTestJob,payload)
      end
    end

    context "when asking to NOT receive more information explicitly" do
      it "should queue a resque job using JOB_KLASS and the payload" do
        ENV["PWWKA_QUEUE_EXTENDED_INFO"] = 'false'
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyLegacyTestJob,payload)
      end
    end

    context "when asking for more information via PWWKA_QUEUE_EXTENDED_INFO" do
      it "should queue a resque job using JOB_KLASS, payload, routing key, and properties as a hash" do
        # Note, using MyLegacyTestJob to ensure this doesn't trigger the method param examination logic and respects
        # the env var, even though it is not used correctly in this case.
        ENV["PWWKA_QUEUE_EXTENDED_INFO"] = 'true'
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyLegacyTestJob,payload,routing_key,properties_hash)
      end
    end

    context "when not asking for more information via PWWKA_QUEUE_EXTENDED_INFO but for a job that can handle it" do
      it "should queue a resque job using JOB_KLASS, payload, routing key, and properties as a hash" do
        ENV["JOB_KLASS"] = MyNewTestJob.name
        ENV.delete("PWWKA_QUEUE_EXTENDED_INFO")
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyNewTestJob,payload,routing_key,properties_hash)
      end
    end

    after do
      ENV.delete("JOB_KLASS")
      ENV.delete("PWWKA_QUEUE_EXTENDED_INFO")
    end
  end
end
