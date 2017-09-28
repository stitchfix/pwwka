module Pwwka
  module ErrorHandlers
  end
end

require_relative "error_handlers/chain"
require_relative "error_handlers/base_error_handler"
require_relative "error_handlers/crash"
require_relative "error_handlers/nack_and_requeue_once"
require_relative "error_handlers/nack_and_ignore"
