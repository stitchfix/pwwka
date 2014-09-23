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
      raise_if_delayed_not_allowed
      @delayed_exchange ||= channel.fanout(configuration.delayed_exchange_name, durable: true)
    end

    def delayed_queue
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
      raise ConfigurationError unless configuration.allow_delayed?
    end

    def connection_close
      channel.close
      connection.close
    end

  end
end
