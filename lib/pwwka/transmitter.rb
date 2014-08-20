module Pwwka
  class Transmitter

    extend Pwwka::Logging
    include Pwwka::Logging

    def self.send_message!(payload, routing_key)
      new.send_message!(payload, routing_key)
      info "AFTER Transmitting Message on #{routing_key} -> #{payload}"
    end

    def self.send_message_safely(payload, routing_key)
      begin
        send_message!(payload, routing_key)
      rescue => e
        error "ERROR Transmitting Message on #{routing_key} -> #{payload}: #{e}"
        false
      end  
    end

    def send_message!(payload, routing_key)
      info "START Transmitting Message on #{routing_key} -> #{payload}"
      channel_connector = ChannelConnector.new 
      channel_connector.topic_exchange.publish(
        payload.to_json,
        routing_key: routing_key,
        persistent: true)
      channel_connector.connection_close
      # if it gets this far it has succeeded
      info "END Transmitting Message on #{routing_key} -> #{payload}"
      true
    end
  end
end
