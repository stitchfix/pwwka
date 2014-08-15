module Pwwka
  class ChannelConnector

    attr_reader :connection
    attr_reader :topic_exchange_name
    attr_reader :channel

    # The channel_connector starts the connection to the message_bus
    # so it should only be instantiated by a method that has a strategy
    # for closing the connection
    def initialize
      configuration        = Pwwka.configuration
      connection_options   = {automatically_recover: false}.merge(configuration.options)
      @connection          = Bunny.new(configuration.rabbit_mq_host,
                                  connection_options)
      @topic_exchange_name = configuration.topic_exchange_name
      @connection.start
      @channel             = @connection.create_channel
    end

    def topic_exchange
      @topic_exchange ||= channel.topic(topic_exchange_name, durable: true)
    end

    def connection_close
      channel.close
      connection.close
    end

  end
end