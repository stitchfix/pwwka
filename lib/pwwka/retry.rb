module Pwwka
  module Retry

    extend Pwwka::Logging

    module ClassMethods

      attr_accessor :retry_count
      def setup_retry
        self.retry_count  = 0
      end

      def message_retries(retry_count)
        self.retry_count  = retry_count
      end

      def do_retry?
        self.retry_count > 0
      end

    end

    module InstanceMethods

    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.send :setup_retry
    end

  end

  class RetryInjector
    def self.inject(handler_klass)
      handler_klass.include(Pwwka::Retry) unless handler_klass.respond_to?(:message_retries)
    end
  end

end
