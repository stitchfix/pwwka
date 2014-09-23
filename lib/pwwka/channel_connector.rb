module Pwwka
  class ChannelConnector

    attr_reader :connection
    attr_reader :configuration
    attr_reader :channel

    # The channel_connector starts the connection to the message_bus
    # so it should only be instantiated by a method that has a strategy
    # for closing the connection
    def initialize
      @configuration     = Pwwka.configuration
      connection_options = {automatically_recover: false}.merge(configuration.options)
      @connection        = Bunny.new(configuration.rabbit_mq_host,
                                  connection_options)
      @connection.start
      @channel           = @connection.create_channel
    end

    def topic_exchange
      @topic_exchange ||= channel.topic(configuration.topic_exchange_name, durable: true)
    end

    def delayed_exchange
      @delayed_exchange ||= channel.fanout(configuration.delayed_exchange_name, durable: true)
    end

    def connection_close
      channel.close
      connection.close
    end

  end
end
