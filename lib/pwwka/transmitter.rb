module Pwwka
  class Transmitter

    extend Pwwka::Logging
    include SuckerPunch::Job

    def self.send_message!(payload, routing_key)
      new.async.send_message!(payload, routing_key)
      info "BACKGROUND AFTER Transmitting Message on #{routing_key} -> #{payload}"
    end

    def self.send_message_safely(payload, routing_key)
      begin
        send_message!(payload, routing_key)
      rescue => e
        error "Error Transmitting Message on #{routing_key} -> #{payload}: #{e}"
        return false
      end  
    end

    # send message asynchronously using sucker_punch
    # call async.send_message!
    def send_message!(payload, routing_key)
      self.class.info "BACKGROUND START Transmitting Message on #{routing_key} -> #{payload}"
      channel_connector = ChannelConnector.new 
      channel_connector.topic_exchange.publish(
        payload.to_json,
        routing_key: routing_key,
        persistent: true)
      channel_connector.connection_close
      # if it gets this far it has succeeded
      self.class.info "BACKGROUND END Transmitting Message on #{routing_key} -> #{payload}"
      return true
    end

  end

end
