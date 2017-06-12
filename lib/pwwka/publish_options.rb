require "securerandom"
module Pwwka
  # Encaspulates the options we pass to `topic_exchange.publish` as well
  # as the various defaults and auto-generated values.
  class PublishOptions
    def initialize(routing_key: ,
                   message_id: :auto_generate,
                   type: ,
                   headers:,
                   expiration: nil)
      @options_hash = {
        routing_key: routing_key,
        message_id: message_id.to_s == "auto_generate" ? SecureRandom.uuid : message_id,
        content_type: "application/json; version=1",
        persistent:  true,
        app_id: Pwwka.configuration.app_id
      }
      @options_hash[:type]       = type unless type.nil?
      @options_hash[:headers]    = headers unless headers.nil?
      @options_hash[:expiration] = expiration unless expiration.nil?
    end

    def message_id
      @options_hash[:message_id]
    end
    def to_h
      @options_hash.merge(timestamp: Time.now.to_i)
    end
  end
end
