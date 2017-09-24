require_relative "base_error_handler"
module Pwwka
  module ErrorHandlers
    class IgnorePayloadFormatErrors < BaseErrorHandler
      def handle_error(receiver,queue_name,payload,delivery_info,exception)
        if exception.kind_of?(JSON::JSONError)
          log("Ignoring JSON error",queue_name,payload,delivery_info,exception)
          receiver.nack(delivery_info.delivery_tag)
          abort_chain
        else
          keep_going
        end
      end
    end

  end
end
