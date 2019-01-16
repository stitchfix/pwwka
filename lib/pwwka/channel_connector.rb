module Pwwka
  class ChannelConnector
    extend Pwwka::Logging
    include Pwwka::Logging

    attr_reader :connection
    attr_reader :configuration
    attr_reader :channel

    # The channel_connector starts the connection to the message_bus
    # so it should only be instantiated by a method that has a strategy
    # for closing the connection
    def initialize(prefetch: nil, connection_name: nil)
      @configuration     = Pwwka.configuration
      connection_options = {automatically_recover: false}.merge(configuration.options)
      connection_options = {client_properties: {connection_name: connection_name}}.merge(connection_options) if connection_name

      begin
        @connection = Bunny.new(configuration.rabbit_mq_host, connection_options)
        @connection.start
      rescue => e
        logf "ERROR Connecting to RabbitMQ", error: e
        @connection.close if @connection
        raise e
      end

      begin
        @channel = @connection.create_channel
      rescue => e
        logf "ERROR Opening RabbitMQ channel", error: e
        @connection.close if @connection
        raise e
      end

      if prefetch
        @channel.prefetch(prefetch.to_i)
      end
    end

    def topic_exchange
      @topic_exchange ||= channel.topic(configuration.topic_exchange_name, durable: true)
    end

    def delayed_exchange
      raise_if_delayed_not_allowed
      @delayed_exchange ||= channel.fanout(configuration.delayed_exchange_name, durable: true)
    end

    def delayed_queue
      # This works by hacking the dead letter exchange concept with a timeout.
      # We set up a delayed exchange that has a delayed queue.  This queue, configured below,
      # sets its dead letter exchange to be the main exchange (topic_exchange above).
      #
      # This means that when a message send to the delayed queue is either nack'ed with no retry OR
      # its TTL expires, it will be sent to the configured dead letter exchange, which is the main topic_exchange.
      #
      # Since nothing is actually consuming messages on the delayed queue, the only way messages can be removed and
      # sent back to the main exchange is if their TTL expires.  As you can see in Pwwka::Transmitter#send_delayed_message!
      # we set an expiration on the message and send it to the delayed exchange.  This means that the delay time is the TTL,
      # so the messages sits in the delayed queue until its TTL/delay expires, and then it's sent onto the 
      # main exchange for everyone to consume.  Thus creating a delay.
      raise_if_delayed_not_allowed
      @delayed_queue ||= begin
        queue = channel.queue("pwwka_delayed_#{Pwwka.environment}", durable: true,
          arguments: {
            'x-dead-letter-exchange' => configuration.topic_exchange_name,
        })
        queue.bind(delayed_exchange)
        queue
      end
    end
    alias :create_delayed_queue :delayed_queue

    def raise_if_delayed_not_allowed
      unless configuration.allow_delayed?
        raise ConfigurationError, "Delayed messages are not allowed. Update your configuration to allow them." 
      end
    end

    def connection_close
      begin
        channel.close
      rescue => e
        logf "ERROR Closing RabbitMQ channel", error: e
      end

      begin
        connection.close
      rescue => e
        logf "ERROR Closing connection to RabbitMQ", error: e
        raise e
      end
    end
  end
end
