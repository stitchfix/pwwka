module Pwwka
  class TestHandler

    attr_reader :channel_connector
    attr_reader :channel
    attr_reader :topic_exchange

    def initialize
      @channel_connector = ChannelConnector.new
      @channel           = channel_connector.channel
      @topic_exchange    = channel_connector.topic_exchange
    end

    # call this method to create the queue used for testing
    # queue needs to be declared before the exchange is published to
    def test_setup
      test_queue
      true
    end

    def test_queue
      @test_queue  ||= begin
                         test_queue  = channel.queue("test-queue", durable: true)
                         test_queue.bind(topic_exchange, routing_key: "*.*")
                         test_queue
                       end
    end

    def get_topic_message_payload_for_tests
      delivery_info, properties, payload  = test_queue.pop
      JSON.parse(payload)
    end

    def get_topic_message_properties_for_tests
      delivery_info, properties, payload  = test_queue.pop
      properties
    end

    def purge_test_queue
      test_queue.purge  
    end

    def test_teardown
      test_queue.delete
      topic_exchange.delete
      channel_connector.connection_close 
    end

  end
end
