require 'spec_helper.rb'

describe Pwwka::Logging do

  class ForLogging
    extend Pwwka::Logging
  end

  it "returns the logger" do
    Pwwka.configure do |c|
      c.logger = MonoLogger.new(STDOUT)
    end
    expect(ForLogging.logger).to be_instance_of(MonoLogger)
  end

  %w(debug info error fatal).each do |severity|
    it "logs #{severity} messages at the class level" do
      expect(ForLogging.respond_to?(severity.to_sym)).to eq true
    end

  end

  describe "#logf" do
    let(:logger) { double(Logger) }

    before do
      @original_logger = Pwwka.configuration.logger
      Pwwka.configuration.logger = logger
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    after do
      Pwwka.configuration.logger = @original_logger
      Pwwka.configuration.payload_logging = @original_payload_logging
    end
    it "logs a printf-style string at info" do
      ForLogging.logf("This is %{test} some %{data}", test: "a test of", data: "data and stuff", ignored: :hopefully)
      expect(logger).to have_received(:info).with("This is a test of some data and stuff")
    end

    it "can log an not-info" do
      ForLogging.logf("This is %{test} some %{data}", test: "a test of", data: "data and stuff", ignored: :hopefully, at: :error)
      expect(logger).to have_received(:error).with("This is a test of some data and stuff")
      expect(logger).not_to have_received(:info)
    end

    context "payload-stripping" do
      [
        :payload,
        "payload",
      ].each do |name|
        it "will strip payload (given as a #{name.class}) if configured" do
          Pwwka.configuration.payload_logging = :error
          ForLogging.logf("This is the payload: %{payload}", name => { foo: "bar" })
          ForLogging.logf("This is also the payload: %{payload}", name => { foo: "bar" }, at: :error)
          expect(logger).to have_received(:info).with("This is the payload: [omitted]")
          expect(logger).to have_received(:error).with("This is also the payload: {:foo=>\"bar\"}")
        end

        it "will strip payload (given as a #{name.class}) of errors, too" do
          Pwwka.configuration.payload_logging = :fatal
          ForLogging.logf("This is the payload: %{payload}", name => { foo: "bar" })
          ForLogging.logf("This is also the payload: %{payload}", name => { foo: "bar" }, at: :error)
          expect(logger).to have_received(:info).with("This is the payload: [omitted]")
          expect(logger).to have_received(:error).with("This is also the payload: [omitted]")
        end
      end
    end

  end
end
