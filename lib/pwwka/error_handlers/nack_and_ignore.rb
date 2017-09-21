require_relative "base_error_handler"
module Pwwka
  module ErrorHandlers
    class NackAndIgnore < BaseErrorHandler
      def handle_error(receiver,queue_name,payload,delivery_info,exception)
        log("Error Processing Message",queue_name,payload,delivery_info,exception)
        receiver.nack(delivery_info.delivery_tag)
        keep_going
      end
    end

  end
end
