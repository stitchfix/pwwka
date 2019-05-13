module Pwwka
  class ConnectionRepository

    def self.instance
      unless !defined?(@current_pid) || @current_pid != Process.pid
        # New process needs a new repository
        @instance = nil
      end
      @instance ||= new
    end

    def self.reset!
      if @instance
        @instance.send(:disconnect!)
      end
      @instance = nil
    end

    def initialize
      @thread_variable_name = :"pwwka_channel_#{object_id}"

      connection_options = Pwwka.configuration.options.merge({
        # Automatic recovery is necessary because the connection is retained
        automatically_recover: true
        # TODO: connection name
      })
      @connection = Bunny.new(Pwwka.configuration.rabbit_mq_host, connection_options)
      @connection.start
    end

    def checkout(**_, &block)
      block.call channel
    end

    def channel
      Thread.current[@thread_variable_name] ||= Channel.new(@connection, Pwwka.configuration)
    end

    private

    def disconnect!
      @connection.close
    end

    class Channel

      attr_reader :channel

      def initialize(connection, configuration)
        @channel = connection.create_channel
        @configuration = configuration
        # TODO: prefetch
      end

      # This is all copied from ChannelConnector.

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
                             queue = channel.queue(
                               "pwwka_delayed_#{Pwwka.environment}",
                               durable: true,
                               arguments: {
                                 'x-dead-letter-exchange' => configuration.topic_exchange_name,
                               }
                             )
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

      private

      attr_reader :configuration

    end
  end
end
