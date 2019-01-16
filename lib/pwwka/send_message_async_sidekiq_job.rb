begin
  require 'sidekiq'
rescue LoadError
end

module Pwwka
  class SendMessageAsyncSidekiqJob
    begin
      include Sidekiq::Worker
      extend Pwwka::Logging

      sidekiq_options queue: 'pwwka_send_message_async', retry: 3

      def perform(payload, routing_key, options = {})
        type = options["type"]
        message_id = options["message_id"] || "auto_generate"
        headers = options["headers"]

        logger.info("Sending message async #{routing_key}, #{payload}")

        message_id = message_id.to_sym if message_id == "auto_generate"

        Pwwka::Transmitter.send_message!(
          payload,
          routing_key,
          type: type,
          message_id: message_id,
          headers: headers,
          on_error: :raise,
        )
      end
    rescue NameError
    end
  end
end

