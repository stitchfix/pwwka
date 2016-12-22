require 'spec_helper'

describe Pwwka::Handling, :legacy do

  class HKlass
    include Pwwka::Handling
  end

  describe "adding handler methods" do

    let(:handling_class) { HKlass.new }
    let(:payload)        { { this: 'that'} }
    let(:routing_key)    { 'sf.merch.style.updated' }

    it "should respond to 'send_message!'" do
      expect(Pwwka::Transmitter).to receive(:send_message!).with(payload, routing_key, delayed: false, delay_by: nil)
      handling_class.send_message!(payload, routing_key, delayed: false, delay_by: nil)
    end

    it "should respond to 'send_message_safely'" do
      expect(Pwwka::Transmitter).to receive(:send_message_safely).with(payload, routing_key, delayed: true, delay_by: 4000)
      handling_class.send_message_safely(payload, routing_key, delayed: true, delay_by: 4000)
    end

  end


end
