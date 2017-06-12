class LoggingReceiver

  def self.reset!
    @messages_received = []
    @metadata = []
  end

  def self.messages_received; @messages_received ||= []; end
  def self.metadata; @metadata ||= []; end

  reset!

  def self.handle!(delivery_info,properties,payload)
    messages_received << [ delivery_info,properties,payload ]
    metadata << properties
  end
end
