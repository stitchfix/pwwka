module Pwwka
  # A handler you can use to examine messages your app sends during tests.
  #
  # To use this:
  #
  # 1. Create an instance and arrange for `test_setup` to be called when
  #    your tests are being setup (e.g.`def setup` or `before`)
  # 2. Arrange for `test_teardown` to be called during teardown of your tests
  # 3. Use the method `pop_message` to examine the message on the queue
  class TestHandler
    include Pwwka::Logging

    attr_reader :channel_connector

    def initialize
      @channel_connector = ChannelConnector.new
    end

    # call this method to create the queue used for testing
    # queue needs to be declared before the exchange is published to
    def test_setup
      test_queue
      true
    end

    def test_queue
      @test_queue  ||= begin
                         test_queue  = channel_connector.channel.queue("test-queue", durable: true)
                         test_queue.bind(channel_connector.topic_exchange, routing_key: "#.#")
                         test_queue
                       end
    end

    # Get the message on the queue as TestHandler::Message
    def pop_message
      # Since publishing happens in a background thread, we might need to wait a little bit.
      5.times do
        message = test_queue.pop
        if message
          return Message.new(*message)
        else
          sleep 0.1
        end
      end
      raise "Failed to retrieve message after 5 tries"
    end

    def get_topic_message_payload_for_tests
      deprecated!(:get_topic_message_payload_for_tests,
                  "Use `pop_message.payload` instead")
      pop_message.payload
    end

    def get_topic_message_properties_for_tests
      deprecated!(:get_topic_message_properties_for_tests,
                  "Use `pop_message.properties` instead")
      pop_message.properties
    end

    def get_topic_message_delivery_info_for_tests
      deprecated!(:get_topic_message_delivery_info_for_tests,
                  "Use `pop_message.delivery_info` instead")
      pop_message.delivery_info
    end

    def purge_test_queue
      test_queue.purge
      channel_connector.delayed_queue.purge if channel_connector.configuration.allow_delayed?
    end

    def test_teardown
      test_queue.delete
      channel_connector.topic_exchange.delete
      # delayed messages
      if Pwwka.configuration.allow_delayed?
        channel_connector.delayed_queue.delete
        channel_connector.delayed_exchange.delete
      end

      channel_connector.connection_close
    end

    # Simple class to hold a popped message.
    #
    # You can either access the message contents directly, or splat
    # it for the most commonly-needed aspects:
    #
    #     delivery_info, payload = @test_handler.pop_message
    class Message
      attr_reader :delivery_info, :properties, :payload
      def initialize(delivery_info, properties, payload)
        @delivery_info = delivery_info
        @properties = properties
        @raw_payload = payload
        @payload = JSON.parse(@raw_payload)
      end

      # Returns the delivery_info, payload, properties, and raw_payload for splat
      # magic.
      def to_ary
        [@delivery_info,@payload,@properties,@raw_payload]
      end
    end

  private

    def deprecated!(method,message)
      warn "#{method} is deprecated: #{message}"
    end

  end
end
