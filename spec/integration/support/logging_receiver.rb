class LoggingReceiver
  def self.reset!; @messages_received = []; end
  def self.messages_received; @messages_received; end

  reset!

  def self.handle!(delivery_info,properties,payload)
    messages_received << [ delivery_info,properties,payload ]
  end
end
