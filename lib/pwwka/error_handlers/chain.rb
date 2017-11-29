module Pwwka
  module ErrorHandlers
    # Given a chain of error handlers, calls them until either
    # one returns false/aborts or we exhaust the chain of handlers
    class Chain
      include Pwwka::Logging
      def initialize(default_handler_chain=[])
        @error_handlers = default_handler_chain
      end
      def handle_error(message_handler_klass,receiver,queue_name,payload,delivery_info,exception)
        logf "Error Processing Message in %{message_handler_klass} due to %{exception} from payload '%{payload}'", at: :error, message_handler_klass: message_handler_klass, exception: exception.message, payload: payload
        if message_handler_klass.respond_to?(:error_handler)
          @error_handlers.unshift(message_handler_klass.send(:error_handler))
        end
        @error_handlers.reduce(true) { |keep_going,error_handler|
          begin
            logf "%{error_handler_class} is being evaluated as part of pwwka's error-handling chain", error_handler_class: error_handler
            if keep_going
              keep_going = error_handler.new.handle_error(receiver,queue_name,payload,delivery_info,exception)
              if keep_going
                logf "%{error_handler_class} has asked to continue pwwka's error-handling chain", error_handler_class: error_handler
              else
                logf "%{error_handler_class} has halted pwwka's error-handling chain", error_handler_class: error_handler
              end
            else
              logf "Skipping %{error_handler_class} as we were asked to abort pwwka's error-handling chain", error_handler_class: error_handler
            end
            keep_going
          rescue StandardError => exception
            logf "'%{error_handler_class}' failed with exception '%{exception}'", at: :fatal, error_handler_class: error_handler, exception: exception
            abort
          end
        }
      end
    end
  end
end
