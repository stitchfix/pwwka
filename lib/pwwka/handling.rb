module Pwwka

  module Handling

    def send_message!(payload, routing_key)
      Pwwka::Transmitter.send_message!(payload, routing_key)
    end

    def send_message_safely(payload, routing_key)
      Pwwka::Transmitter.send_message_safely(payload, routing_key)
    end

  end

end
