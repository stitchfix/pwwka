require 'spec_helper.rb'

module MyAmazingApp
  class Application
  end
end
describe Pwwka::Configuration do

  subject(:configuration) { described_class.new }
  before do
    @env = ENV["RAILS_ENV"]
    ENV["RAILS_ENV"] = "production"
  end
  after do
    ENV["RAILS_ENV"] = @env
  end

  describe "#topic_exchange_name" do
    it "is based on the Pwwka.environment" do
      expect(configuration.topic_exchange_name).to eq("pwwka.topics.production")
    end
  end
  describe "#delayed_exchange_name" do
    it "is based on the Pwwka.environment" do
      expect(configuration.delayed_exchange_name).to eq("pwwka.delayed.production")
    end
  end

  describe "#payload_logging" do
    it "is info by default" do
      expect(configuration.payload_logging).to eq(:info)
    end

    it "can be overridden" do
      configuration.payload_logging = :debug
      expect(configuration.payload_logging).to eq(:debug)
    end
  end

  describe "#app_id" do
    it "returns the value set explicitly" do
      configuration.app_id = "MyApp"
      expect(configuration.app_id).to eq("MyApp")
    end
    it "blows up when not set" do
      expect {
        configuration.app_id
      }.to raise_error(/Could not derive the app_id; you must explicitly set it/)
    end
    context "when inside a Rails app" do
      before do
        rails = Class.new do
          def self.application
            MyAmazingApp::Application.new
          end
        end
        Object.const_set("Rails",rails)
      end
      after do
        Object.send(:remove_const,"Rails")
      end
      it "uses the Rails app name" do
        expect(configuration.app_id).to eq("MyAmazingApp")
      end
    end

    context "when Rails is defined, but not how we expect" do
      before do
        rails = Class.new
        Object.const_set("Rails",rails)
      end
      after do
        Object.send(:remove_const,"Rails")
      end
      it "blows up when not set" do
        expect {
          configuration.app_id
        }.to raise_error(/'Rails' is defined, but it doesn't respond to #application, so could not derive the app_id; you must explicitly set it/)
      end
    end
  end

  describe "#error_handling_chain" do
    before do
      configuration.instance_variable_set("@error_handling_chain",nil)
    end
    context "implicit configuration" do
      context "when requeue_on_error" do
        context "when keep_alive_on_handler_klass_exceptions" do
          it "is NackAndRequeueOnce" do
            configuration.requeue_on_error = true
            configuration.keep_alive_on_handler_klass_exceptions = true
            expect(configuration.error_handling_chain).to eq([Pwwka::ErrorHandlers::IgnorePayloadFormatErrors,Pwwka::ErrorHandlers::NackAndRequeueOnce])
          end
        end
        context "when not keep_alive_on_handler_klass_exceptions" do
          it "is NackAndRequeueOnce,Crash" do
            configuration.requeue_on_error = true
            configuration.keep_alive_on_handler_klass_exceptions = false
            expect(configuration.error_handling_chain).to eq([Pwwka::ErrorHandlers::IgnorePayloadFormatErrors,Pwwka::ErrorHandlers::NackAndRequeueOnce,Pwwka::ErrorHandlers::Crash])
          end
        end
      end
      context "when not requeue_on_error" do
        context "when keep_alive_on_handler_klass_exceptions" do
          it "is NackAndIgnore" do
            configuration.requeue_on_error = false
            configuration.keep_alive_on_handler_klass_exceptions = true
            expect(configuration.error_handling_chain).to eq([Pwwka::ErrorHandlers::IgnorePayloadFormatErrors,Pwwka::ErrorHandlers::NackAndIgnore])
          end
        end
        context "when not keep_alive_on_handler_klass_exceptions" do
          it "is NackAndIgnore,Crash" do
            configuration.requeue_on_error = false
            configuration.keep_alive_on_handler_klass_exceptions = false
            expect(configuration.error_handling_chain).to eq([Pwwka::ErrorHandlers::IgnorePayloadFormatErrors,Pwwka::ErrorHandlers::NackAndIgnore,Pwwka::ErrorHandlers::Crash])
          end
        end
      end
    end
  end
end
