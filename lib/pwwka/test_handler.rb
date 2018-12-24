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
      @channel_connector = Pwwka.configuration.channel_connector_klass.new(queue_name: "test-queue")
    end

    # call this method to create the queue used for testing
    # queue needs to be declared before the exchange is published to
    def test_setup
      channel_connector.bind(routing_key: "#.#")
      true
    end

    # Get the message on the queue as TestHandler::Message
    def pop_message
      delivery_info, properties, payload = channel_connector.pop
      Message.new(delivery_info,
                  properties,
                  payload)
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
      channel_connector.purge
    end

    def test_teardown
      channel_connector.teardown
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
