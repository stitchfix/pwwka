require_relative "base_error_handler"
module Pwwka
  module ErrorHandlers
    class Crash < BaseErrorHandler
      def handle_error(receiver,queue_name,payload,delivery_info,e)
        raise Interrupt,"Exiting due to exception #{e.inspect}"
        abort_chain
      end
    end
  end
end
