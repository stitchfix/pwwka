require 'spec_helper.rb'

describe Pwwka::RedisLogger do

  let(:payload)     { {thing_id: 12345} }
  let(:routing_key) { "this.that.12345.doned" }
  let(:queue_name)  { "redis_logger_test" }


  describe "::log_the_message" do
    
    it "should log an acked message" do

    end

    it "should log an unacked message" do

    end

    it "should update the log a for a newly acked message" do

    end

  end

  describe "#message_key" do

    it "should create the correct message_key" do
      redis_logger  = Pwwka::RedisLogger.new(routing_key, payload, queue_name)
      expect(redis_logger.message_key).to eq('thing')

    end

  end

end

