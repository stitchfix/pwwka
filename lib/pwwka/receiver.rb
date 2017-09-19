module Pwwka
  class Receiver

    extend Pwwka::Logging

    attr_reader :channel_connector
    attr_reader :channel
    attr_reader :topic_exchange
    attr_reader :queue_name
    attr_reader :routing_key

    def initialize(queue_name, routing_key)
      @queue_name        = queue_name
      @routing_key       = routing_key
      @channel_connector = ChannelConnector.new
      @channel           = @channel_connector.channel
      @topic_exchange    = @channel_connector.topic_exchange
    end

    def self.subscribe(handler_klass, queue_name, routing_key: "#.#", block: true)
      raise "#{handler_klass.name} must respond to `handle!`" unless handler_klass.respond_to?(:handle!)
      receiver  = new(queue_name, routing_key)
      begin
        info "Receiving on #{queue_name}"
        receiver.topic_queue.subscribe(manual_ack: true, block: block) do |delivery_info, properties, payload|
          begin
            payload = ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(payload))
            handler_klass.handle!(delivery_info, properties, payload)
            receiver.ack(delivery_info.delivery_tag)
            logf "Processed Message on %{queue_name} -> %{payload}, %{routing_key}", queue_name: queue_name, payload: payload, routing_key: delivery_info.routing_key
          rescue => e
            error_options = {
               queue_name: queue_name,
                  payload: payload,
              routing_key: delivery_info.routing_key,
                exception: e
            }
            if Pwwka.configuration.requeue_on_error && !delivery_info.redelivered
              log_error "Retrying an Error Processing Message", error_options
              receiver.nack_requeue(delivery_info.delivery_tag)
            else
              log_error "Error Processing Message", error_options
              receiver.nack(delivery_info.delivery_tag)
            end
            if handler_klass.respond_to?(:on_unhandled_error)
              handler_klass.on_unhandled_error(e)
            elsif Pwwka.configuration.keep_alive_on_handler_klass_exceptions?
              # no op
            else
              raise Interrupt,"Exiting due to exception #{e.inspect}"
            end
          end
        end
      rescue Interrupt => _
        # TODO: trap TERM within channel.work_pool
        info "Interrupting queue #{queue_name} subscriber safely"
        receiver.channel_connector.connection_close
      end
      return receiver
    end

    def topic_queue
      @topic_queue ||= begin
        queue = channel.queue(queue_name, durable: true, arguments: {})
        queue.bind(topic_exchange, routing_key: routing_key)
        queue
      end
    end

    def ack(delivery_tag)
      channel.acknowledge(delivery_tag, false)
    end

    def nack(delivery_tag)
      channel.nack(delivery_tag, false, false)
    end

    def nack_requeue(delivery_tag)
      channel.nack(delivery_tag, false, true)
    end

    def drop_queue
      topic_queue.purge
      topic_queue.delete
    end

    def test_teardown
      drop_queue
      topic_exchange.delete
      channel_connector.connection_close
    end

  private

    def self.log_error(message,options)
      options[:message] = message
      options[:backtrace] = options.fetch(:exception).backtrace.join(';')
      logf "%{message} on %{queue_name} -> %{payload}, %{routing_key}: %{exception}: %{backtrace}", options
    end

  end
end
