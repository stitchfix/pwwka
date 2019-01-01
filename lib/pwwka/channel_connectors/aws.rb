require 'aws-sdk-sqs'
require 'aws-sdk-sns'

require_relative 'base'

module Pwwka
  class ChannelConnectorAWS < Pwwka::ChannelConnectorBase

    class MessageAdapterDeliveryInfo
      attr_accessor :delivery_tag, :routing_key

      def initialize(delivery_tag:, routing_key:)
        @delivery_tag = delivery_tag
        @routing_key = routing_key
      end
    end

    class MessageAdapter
      def initialize(message, queue_name)
        @message = message
        @queue_name = queue_name
      end

      def delivery_info
        return MessageAdapterDeliveryInfo.new(
          delivery_tag: @message.message_id,
          routing_key: @queue_name
        )
      end

      def properties
        @message.attributes
      end

      def payload
        JSON.load(@message.body)
      end
    end

    attr_reader :configuration

    # The channel_connector starts the connection to the message_bus
    # so it should only be instantiated by a method that has a strategy
    # for closing the connection
    def initialize(prefetch: nil, connection_name: nil, queue_name: nil)
      @configuration     = Pwwka.configuration
      @sqs_client        = Aws::SQS::Client.new({}.merge(configuration.sqs))
      @sns_client        = Aws::SNS::Client.new({}.merge(configuration.sns))
      @queue_name        = queue_name
      @prefetch          = prefetch ? prefetch.to_i : 1

    end

    # TODO: (2018-12-31) AK - There isn't a great way to do deylayed messages
    # when publishing to SNS. There is probably a way with SQS delayed and a lambda
    # that would republish to SNS.


    def publish(payload, publish_options)
      sns_client.publish({
        topic_arn: topic_arn,
        message: payload,
        message_attributes: {
          "content_type" => {
            data_type: "String",
            string_value: "application/json",
          },
        },
      })
    end

    def raise_if_delayed_not_allowed
      unless configuration.allow_delayed?
        raise ConfigurationError, "Delayed messages are not allowed. Update your configuration to allow them."
      end
    end

    def connection_close
      # Probably a no-op
    end

    def bind(routing_key:)
      # Not sure yet
    end

    # This method is only used by the test_handler code
    def pop
      resp = sqs_client.receive_message({
        queue_url: queue_url,
        message_attribute_names: ["MessageAttributeName"],
        max_number_of_messages: 1,
        visibility_timeout: 60,
        wait_time_seconds: 1,
      })

      MessageAdapter.new(resp.messages[0], queue_name)
    end

    def purge
      sqs_client.purge_queue({
        queue_url: queue_url,
      })
    end

    def delete
      # This will probabably be a no-op
    end

    def teardown
      # No op
    end

    def subscribe(manual_ack: true, block: true, &handler)
      poller.poll(max_number_of_messages:@prefetch, skip_delete: manual_ack) do |messages|
        messages = [messages] if messages.instance_of? Aws::SQS::Types::Message
        messages.each do |msg|
          message = MessageAdapter.new(msg, queue_name)
          handler.yield(message.delivery_info, message.properties, message.payload)
        end

        throw :stop_polling unless block
      end
    end

    def ack(receipt_handle)
      sqs_client.delete_message({
        queue_url: queue_url,
        receipt_handle: receipt_handle
      })
    end

    def nack(receipt_handle)
      # It seems that nack and ack are the same
      # operation here.
      sqs_client.delete_message({
        queue_url: queue_url,
        receipt_handle: receipt_handle
      })
    end

    def nack_requeue(delivery_tag)
      # This is a no-op because of the way that SQS works messages will
      # show up again if they aren't deleted.
    end

    def message_count
      resp = sqs_client.get_queue_attributes({
        queue_url: queue_url,
        attribute_names: ["ApproximateNumberOfMessages"]
      })

      resp.attributes["ApproximateNumberOfMessages"].to_i
    end

    private

    attr_reader :queue_name, :sns_client, :sqs_client

    def topic_arn
      "aws:sns:#{configuration.aws_region}:#{configuration.aws_account_id}:#{configuration.topic_exchange_name}"
    end

    def poller
      Aws::SQS::QueuePoller.new(queue_url, {
        client: sqs_client
      })
    end

    def queue_url
      @queue_url ||= begin
        resp = sqs_client.get_queue_url({
          queue_name: queue_name
        })
        resp.queue_url
      end
    end

  end
end
