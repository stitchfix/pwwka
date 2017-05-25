module Pwwka
  class SendMessageAsyncJob

    extend Pwwka::Logging

    @queue = 'pwwka_send_message_async'

    extend Resque::Plugins::ExponentialBackoff rescue nil # Optional
    @backoff_strategy = Pwwka.configuration.send_message_resque_backoff_strategy

    def self.perform(payload, routing_key, options = {})

      type       = options["type"]
      message_id = options["message_id"] || "auto_generate"
      headers    = options["headers"]

      info("Sending message async #{routing_key}, #{payload}")
      message_id = message_id.to_sym if message_id == "auto_generate"
      Pwwka::Transmitter.send_message!(
        payload,
        routing_key,
        type: type,
        message_id: message_id,
        headers: headers,
        on_error: :raise)
    end
  end
end
