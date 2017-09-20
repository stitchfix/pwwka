module Pwwka
  module ErrorHandlers
    class BaseErrorHandler
      include Pwwka::Logging
      def handle_error(receiver,queue_name,payload,delivery_info,exception)
        raise "subclass must implement"
      end

    private

      def log(message,queue_name,payload,delivery_info,exception)
        logf "%{message} on %{queue_name} -> %{payload}, %{routing_key}: %{exception}: %{backtrace}", {
          message: message,
          queue_name: queue_name,
          payload: payload,
          routing_key: delivery_info.routing_key,
          exception: exception,
          backtrace: exception.backtrace.join(";"),
        }
      end

      # Subclasses can call these methods instead of
      # using true/false to more clearly indicate their intent
      def keep_going
        true
      end

      def abort_chain
        false
      end
    end
  end
end
