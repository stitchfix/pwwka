require "spec_helper"

describe Pwwka::ErrorHandlers::Chain do
  let(:subject) { described_class.new(default_handler_chain) }

  describe "#handle_error" do
    xit "logs exceptions that occur in the error handling chain" do
    end
  end
end
