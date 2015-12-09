module Pwwka
  class SendMessageAsyncJob

    extend Pwwka::Logging

    @queue = 'pwwka_send_message_async'

    extend Resque::Plugins::ExponentialBackoff rescue nil # Optional
    @backoff_strategy = Pwwka.configuration.send_message_resque_backoff_strategy

    def self.perform(payload, routing_key)
      info("Sending message async #{routing_key}, #{payload}")
      Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :raise)
    end
  end
end
