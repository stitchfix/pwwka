require_relative "publish_options"

begin  # optional dependency
  require 'resque'
  require 'resque-retry'
rescue LoadError
end

module Pwwka
  # Primary interface for sending messages.
  #
  # Example:
  #
  #     # Send a message, blowing up if there's any problem
  #     Pwwka::Transmitter.send_message!({ user_id: @user.id }, "users.user.activated")
  #
  #     # Send a message, logging if there's any problem
  #     Pwwka::Transmitter.send_message_safely({ user_id: @user.id }, "users.user.activated")
  class PersistentTransmitter

    extend Pwwka::Logging
    include Pwwka::Logging

    DEFAULT_DELAY_BY_MS = 5000

    attr_reader :channel_connector
   
    def initialize
      @channel_connector = ChannelConnector.new(connection_name: "p: #{Pwwka.configuration.app_id} #{Pwwka.configuration.process_name}".strip)
    end

    def send_message!(payload, routing_key, type: nil, headers: nil, message_id: :auto_generate)
      publish_options = Pwwka::PublishOptions.new(
        routing_key: routing_key,
        message_id: message_id,
        type: type,
        headers: headers
      )
      logf "START Transmitting Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      channel_connector.topic_exchange.publish(payload.to_json, publish_options.to_h)
      # if it gets this far it has succeeded
      logf "END Transmitting Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      true
    end

    class << self
        private :new
        
        def batch(routing_key, type: nil, headers: nil, message_id: :auto_generate)
          transmitter = new
          yield(transmitter)
        ensure
          transmitter.channel_connector.connection_close
        end

    end
  end
end
