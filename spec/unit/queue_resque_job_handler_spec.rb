require 'spec_helper'
require 'pwwka/queue_resque_job_handler'

class MyTestJob
end

describe Pwwka::QueueResqueJobHandler do

  describe "::handle!" do
    let(:job_class) { MyTestJob }
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
      ENV["JOB_KLASS"] = MyTestJob.name
    end

    context "when not asking for more information explicitly" do
      it "should queue a resque job using JOB_KLASS and the payload" do
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyTestJob,payload)
      end
    end

    context "when asking to NOT receive more information explicitly" do
      it "should queue a resque job using JOB_KLASS and the payload" do
        ENV["PWWKA_QUEUE_EXTENDED_INFO"] = 'false'
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyTestJob,payload)
      end
    end

    context "when asking for more information via PWWKA_QUEUE_EXTENDED_INFO" do
      it "should queue a resque job using JOB_KLASS, payload, routing key, and properties as a hash" do
        ENV["PWWKA_QUEUE_EXTENDED_INFO"] = 'true'
        described_class.handle!(delivery_info,properties,payload)
        expect(Resque).to have_received(:enqueue).with(MyTestJob,payload,routing_key,properties_hash)
      end
    end

    after do
      ENV.delete("JOB_KLASS")
      ENV.delete("PWWKA_QUEUE_EXTENDED_INFO")
    end
  end
end
