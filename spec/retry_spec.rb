require 'spec_helper.rb'

describe Pwwka::Retry do

  class RetryHandler
    include Pwwka::Retry

    message_retries 5

    def self.handle!(delivery_info, properties, payload)
      return "made it here"
    end

  end

  class NoRetryHandler

    def self.handle!(delivery_info, properties, payload)
      return "made it here"
    end

  end

  describe "RetryInjector" do

    it "should inject the retry module into a handler that doesn't have it" do
      Pwwka::RetryInjector.inject(NoRetryHandler)
      expect(NoRetryHandler.respond_to?(:message_retries)).to be_true
    end

    it "should not inject the retry module into a handler that has it already" do
      Pwwka::RetryInjector.inject(RetryHandler)
      expect(RetryHandler.respond_to?(:message_retries)).to be_true
    end

  end

  describe "::message_retries" do

    it "should set the retry count" do
      expect(RetryHandler.retry_count).to eq(5)
    end

  end

  describe "::do_retry?" do

    it "should return true if there is a positive integer retry count" do
      expect(RetryHandler.do_retry?).to be_true
    end

    it "should return false if there is a zero retry count" do
      Pwwka::RetryInjector.inject(NoRetryHandler)
      expect(NoRetryHandler.do_retry?).to be_false
    end

  end

end
