require_relative "base_error_handler"
module Pwwka
  module ErrorHandlers
    class NackAndRequeueOnce < BaseErrorHandler
      def handle_error(receiver,queue_name,payload,delivery_info,exception)
        if delivery_info.redelivered
          log("Error Processing Message",queue_name,payload,delivery_info,exception)
          receiver.nack(delivery_info.delivery_tag)
        else
          log("Retrying an Error Processing Message",queue_name,payload,delivery_info,exception)
          receiver.nack_requeue(delivery_info.delivery_tag)
        end
        keep_going
      end
    end
  end
end
