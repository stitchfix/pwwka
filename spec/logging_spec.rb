require 'spec_helper.rb'

describe Pwwka::Logging do

  class ForLogging
    extend Pwwka::Logging
  end

  it "returns the logger" do
    expect(ForLogging.logger).to be_instance_of(MonoLogger)
  end

  %w(debug info error fatal).each do |severity|
    it "logs #{severity} messages at the class level" do
      expect(ForLogging.respond_to?(severity.to_sym)).to eq true
    end

  end
end
