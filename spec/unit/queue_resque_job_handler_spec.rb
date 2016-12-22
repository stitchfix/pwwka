require 'spec_helper'
require 'pwwka/queue_resque_job_handler'

class MyTestJob
end

describe Pwwka::QueueResqueJobHandler do

  describe "::handle!" do
    let(:job_class) { MyTestJob }
    let(:delivery_info) { double("delivery info") }
    let(:properties) { double("properties") }
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

      described_class.handle!(delivery_info,properties,payload)
    end

    it "should queue a resque job using JOB_KLASS and payload" do
      expect(Resque).to have_received(:enqueue).with(MyTestJob,payload)
    end

    after do
      ENV.delete("JOB_KLASS")
    end
  end
end
