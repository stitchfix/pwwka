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
  #       # do another thing, then queue message
  #       message_queuer.queue_message(payload: {the: 'other'}, routing_key: 'go.somewhere.else')
  #     end
  #     # send the queued messages if we make it out of the transaction alive
  #     message_queuer.send_messages_safely


  class MessageQueuer

    include Handling

    attr_reader :message_queue

    def initialize(message_queue = [])
      @message_queue  = message_queue
    end

    def queue_message(payload:, routing_key:)
      self.class.new(message_queue.push([payload, routing_key]))
    end

    def send_messages_safely
      message_queue.each do |message|
        send_message_safely(message[0], message[1])
      end
      clear_messages
    end

    def send_messages!
      message_queue.each do |message|
        send_message!(message[0], message[1])
      end
      clear_messages
    end

    def clear_messages
      @message_queue.clear
      self.class.new
    end

  end
end
