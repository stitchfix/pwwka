module Pwwka
  # Queue messages for sending in a batch
  # Primarily used when multiple messages need to sent from within a
  # transaction block
  #
  # Example:
  #
  #     # instantiate a message_queuer object
  #     message_queuer  = MessageQueuerService.new
  #     ActiveRecord::Base.transaction do
  #       # do a thing, then queue message
  #       message_queuer.queue_message(payload: {this: 'that'}, routing_key: 'go.to.there')
  #
  #       # do another thing, then queue a delayed message
  #       message_queuer.queue_message(payload: {the: 'other'}, routing_key: 'go.somewhere.else', delayed: true, delay_by: 3000)
  #     end
  #     # send the queued messages if we make it out of the transaction alive
  #     message_queuer.send_messages_safely


  class MessageQueuer

    include Handling

    attr_reader :message_queue

    def initialize()
      @message_queue  = []
    end

    def queue_message(payload: nil, routing_key: nil, delayed: false, delay_by: nil)
      raise 'Missing payload' if payload.nil?
      raise 'Missing routing_key' if routing_key.nil?
      message_queue.push({
            payload: payload,
        routing_key: routing_key,
            delayed: delayed,
           delay_by: delay_by
      })
    end

    def send_messages_safely
      message_queue.each do |message|
        delay_hash  = {delayed: message[:delayed], delay_by: message[:delay_by]}.delete_if{|_,v|!v}
        send_message_safely(*message_arguments(message))
      end
      clear_messages
    end

    def send_messages!
      message_queue.each do |message|
        payload, routing_key, options = *message_arguments(message)
        options ||= {}
        send_message!(payload, routing_key, **options)
      end
      clear_messages
    end

    def clear_messages
      @message_queue.clear
    end

    private
    def message_arguments(message)
      delay_hash  = {delayed: message[:delayed], delay_by: message[:delay_by]}.delete_if{|_,v|!v}
      [message[:payload], message[:routing_key], (delay_hash.any? ? delay_hash : nil)].compact
    end

  end
end
