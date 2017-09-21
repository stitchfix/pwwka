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
        if message_handler_klass.respond_to?(:error_handler)
          @error_handlers.unshift(message_handler_klass.send(:error_handler))
        end
        @error_handlers.reduce(true) { |keep_going,error_handler|
          if keep_going
            keep_going = error_handler.new.handle_error(receiver,queue_name,payload,delivery_info,exception)
            unless keep_going
              logf "%{error_handler_class} has halted to error-handling chain", error_handler_class: error_handler.class
            end
          else
            logf "Skipping %{error_handler_class} as we were asked to abort previously", error_handler_class: error_handler.class
          end
          keep_going
        }
      end
    end
  end
end
