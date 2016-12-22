require 'spec_helper'

describe Pwwka::TestHandler::Message do
  let(:delivery_info) { double("delivery info") }
  let(:properties) { double("properties") }
  let(:payload) { { foo: "bar" }.to_json }

  subject(:message) { described_class.new(delivery_info,properties,payload) }

  describe "attributes" do
    specify { expect(message.delivery_info).to eq(delivery_info) }
    specify { expect(message.properties).to    eq(properties) }
    specify { expect(message.payload).to       eq(JSON.parse(payload)) }
  end

  describe "splatting" do
    it "extracts pieces during a splat" do
      extracted_delivery_info,extracted_payload,extracted_properties,extracted_raw_payload = message
      expect(extracted_delivery_info).to  eq(delivery_info)
      expect(extracted_properties).to     eq(properties)
      expect(extracted_payload).to        eq(JSON.parse(payload))
      expect(extracted_raw_payload).to    eq(payload)
    end
  end

end
