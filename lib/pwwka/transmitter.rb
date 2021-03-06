require_relative "publish_options"

begin  # optional dependency
  require 'resque'
  require 'resque-retry'
rescue LoadError
end

module Pwwka
  # Primary interface for sending messages.
  #
  # Example:
  #
  #     # Send a message, blowing up if there's any problem
  #     Pwwka::Transmitter.send_message!({ user_id: @user.id }, "users.user.activated")
  #
  #     # Send a message, logging if there's any problem
  #     Pwwka::Transmitter.send_message_safely({ user_id: @user.id }, "users.user.activated")
  class Transmitter

    extend Pwwka::Logging
    include Pwwka::Logging

    DEFAULT_DELAY_BY_MS = 5000

    attr_reader :caller_manages_connector
    attr_reader :channel_connector

    def initialize(channel_connector: nil)
      if channel_connector
        @caller_manages_connector = true
        @channel_connector = channel_connector
      else
        @caller_manages_connector = false
        @channel_connector = ChannelConnector.new(connection_name: "p: #{Pwwka.configuration.app_id} #{Pwwka.configuration.process_name}".strip)
      end
    end

    # Send an important message that must go through.  This method allows any raised exception
    # to pass through.
    #
    # payload:: Hash of what you'd like to include in your message
    # routing_key:: String routing key for the message
    # delayed:: Boolean send this message later
    # delay_by:: Integer milliseconds to delay the message
    # type:: A string describing the type.  This + your configured app_id should be unique to your entire ecosystem.
    # message_id:: If specified (which generally you should not do), sets the id of the message.  If omitted, a GUID is used.
    # headers:: A hash of arbitrary headers to include in the AMQP attributes
    # on_error:: What is the behavior of
    # - :ignore (aka as send_message_safely)
    # - :raise
    # - :resque -- use Resque to try to send the message later
    # - :retry_async -- use the configured background job processor to retry sending the message later
    #
    # Returns true
    #
    # Raises any exception generated by the innerworkings of this library.
    def self.send_message!(payload, routing_key,
                           on_error: :raise,
                           delayed: false,
                           delay_by: nil,
                           type: nil,
                           message_id: :auto_generate,
                           headers: nil,
                           channel_connector: nil
                          )
      if delayed
        new(channel_connector: channel_connector).send_delayed_message!(*[payload, routing_key, delay_by].compact, type: type, headers: headers, message_id: message_id)
      else
        new(channel_connector: channel_connector).send_message!(payload, routing_key, type: type, headers: headers, message_id: message_id)
      end
      logf "AFTER Transmitting Message on %{routing_key} -> %{payload}",routing_key: routing_key, payload: payload
      true
    rescue => e

      logf "ERROR Transmitting Message on %{routing_key} -> %{payload} : %{error}", routing_key: routing_key, payload: payload, error: e, at: :error

      case on_error

        when :raise
          raise e

        when :resque, :retry_async
          begin
            send_message_async(payload, routing_key, delay_by_ms: delayed ? delay_by || DEFAULT_DELAY_BY_MS : 0)
          rescue => exception
            warn(exception.message)
            raise e
          end

        else # ignore
      end
      false
    end

    # Enqueue the message with the configured background processor.
    # - :delay_by_ms:: Integer milliseconds to delay the message. Default is 0.
    def self.send_message_async(payload, routing_key,
                                delay_by_ms: 0,
                                type: nil,
                                message_id: :auto_generate,
                                headers: nil)
      background_job_processor = Pwwka.configuration.background_job_processor
      job = Pwwka.configuration.async_job_klass

      if background_job_processor == :resque
        resque_args = [job, payload, routing_key]

        unless type == nil && message_id == :auto_generate && headers == nil
          # NOTE: (jdlubrano)
          # Why can't we pass these options all of the time?  Well, if a user
          # of pwwka has configured their own async_job_klass that only has an
          # arity of 2 (i.e. payload and routing key), then passing these options
          # as an additional argument would break the user's application.  In
          # order to maintain compatibility with preceding versions of Pwwka,
          # we need to ensure that the same arguments passed into this method
          # result in compatible calls to enqueue any Resque jobs.
          resque_args << { type: type, message_id: message_id, headers: headers }
        end

        if delay_by_ms.zero?
          Resque.enqueue(*resque_args)
        else
          Resque.enqueue_in(delay_by_ms/1000, *resque_args)
        end
      elsif background_job_processor == :sidekiq
        options = { delay_by_ms: delay_by_ms, type: type, message_id: message_id, headers: headers }
        job.perform_async(payload, routing_key, options)
      end
    end

    # Send a less important message that doesn't have to go through. This eats
    # any `StandardError` and logs it, returning false rather than blowing up.
    #
    # payload:: Hash of what you'd like to include in your message
    # routing_key:: String routing key for the message
    # delayed:: Boolean send this message later
    # delay_by:: Integer milliseconds to delay the message
    #
    # Returns true if the message was sent, false otherwise
    # @deprecated This is ignoring a message. ::send_message supports this explicitly.
    def self.send_message_safely(payload, routing_key, delayed: false, delay_by: nil, message_id: :auto_generate)
      send_message!(payload, routing_key, delayed: delayed, delay_by: delay_by, on_error: :ignore)
    end

    def send_message!(payload, routing_key, type: nil, headers: nil, message_id: :auto_generate)
      publish_options = Pwwka::PublishOptions.new(
        routing_key: routing_key,
        message_id: message_id,
        type: type,
        headers: headers
      )
      logf "START Transmitting Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      channel_connector.topic_exchange.publish(payload.to_json, publish_options.to_h)
      # if it gets this far it has succeeded
      logf "END Transmitting Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      true
    ensure
      unless caller_manages_connector
        channel_connector.connection_close
      end
    end


    def send_delayed_message!(payload, routing_key, delay_by = DEFAULT_DELAY_BY_MS, type: nil, headers: nil, message_id: :auto_generate)
      channel_connector.raise_if_delayed_not_allowed
      publish_options = Pwwka::PublishOptions.new(
        routing_key: routing_key,
        message_id: message_id,
        type: type,
        headers: headers,
        expiration: delay_by
      )
      logf "START Transmitting Delayed Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      channel_connector.create_delayed_queue
      channel_connector.delayed_exchange.publish(payload.to_json,publish_options.to_h)
      # if it gets this far it has succeeded
      logf "END Transmitting Delayed Message on id[%{id}] %{routing_key} -> %{payload}", id: publish_options.message_id, routing_key: routing_key, payload: payload
      true
    ensure
      unless caller_manages_connector
        channel_connector.connection_close
      end
    end

  end
end
