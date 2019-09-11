require 'bunny'
require 'mono_logger'

module Pwwka
  class ConfigurationError < StandardError; end
  class Configuration

    attr_accessor :rabbit_mq_host
    attr_accessor :topic_exchange_name
    attr_accessor :delayed_exchange_name
    attr_accessor :logger
    attr_accessor :log_level
    attr_accessor :options
    attr_accessor :background_job_processor
    attr_accessor :send_message_resque_backoff_strategy
    attr_accessor :default_prefetch
    attr_accessor :process_name
    attr_reader   :requeue_on_error
    attr_writer   :app_id
    attr_writer   :async_job_klass
    attr_writer   :error_handling_chain

    def initialize
      @rabbit_mq_host        = nil
      @topic_exchange_name   = "pwwka.topics.#{Pwwka.environment}"
      @delayed_exchange_name = "pwwka.delayed.#{Pwwka.environment}"
      @logger                = MonoLogger.new(STDOUT)
      @log_level             = :info
      @options               = {}
      @send_message_resque_backoff_strategy = [5,                  #intermittent glitch?
                                               60,                 # quick interruption
                                               600, 600, 600] # longer-term outage?
      @requeue_on_error = false
      @keep_alive_on_handler_klass_exceptions = false
      @background_job_processor = :resque
      @default_prefetch = nil
      @receive_raw_payload = false
      @process_name = ""
    end

    def keep_alive_on_handler_klass_exceptions?
      @keep_alive_on_handler_klass_exceptions
    end

    def app_id
      if @app_id.to_s.strip == ""
        if defined?(Rails)
          if Rails.respond_to?(:application) && Rails.respond_to?(:version)
            # Module#module_parent is the preferred technique, but we keep usage
            # of the deprecated Module#parent for Rails 5 compatibility. see
            # https://github.com/stitchfix/pwwka/issues/91 for context.
            app_klass = Rails.application.class
            app_parent = Rails.version =~ /^6/ ? app_klass.module_parent : app_klass.parent
            app_parent.name
          else
            raise "'Rails' is defined, but it doesn't respond to #application or #version, so could not derive the app_id; you must explicitly set it"
          end
        else
          raise "Could not derive the app_id; you must explicitly set it"
        end
      else
        @app_id
      end
    end

    def async_job_klass
      @async_job_klass || background_jobs[background_job_processor]
    end

    def payload_logging
      @payload_logging || :info
    end

    def payload_logging=(new_payload_logging_level)
      @payload_logging = new_payload_logging_level
    end

    def allow_delayed?
      options[:allow_delayed]
    end

    def error_handling_chain
      @error_handling_chain ||= begin
                                  klasses = [ Pwwka::ErrorHandlers::IgnorePayloadFormatErrors ]
                                  if self.requeue_on_error
                                    klasses << Pwwka::ErrorHandlers::NackAndRequeueOnce
                                  else
                                    klasses << Pwwka::ErrorHandlers::NackAndIgnore
                                  end
                                  unless self.keep_alive_on_handler_klass_exceptions?
                                    klasses << Pwwka::ErrorHandlers::Crash
                                  end
                                  klasses
                                end
    end

    def keep_alive_on_handler_klass_exceptions=(val)
      @keep_alive_on_handler_klass_exceptions = val
      if @keep_alive_on_handler_klass_exceptions
        @error_handling_chain.delete(Pwwka::ErrorHandlers::Crash)
      elsif !@error_handling_chain.include?(Pwwka::ErrorHandlers::Crash)
        @error_handling_chain << Pwwka::ErrorHandlers::Crash
      end
    end

    def requeue_on_error=(val)
      @requeue_on_error = val
      if @requeue_on_error
        index = error_handling_chain.index(Pwwka::ErrorHandlers::NackAndIgnore)
        if index
          @error_handling_chain[index] = Pwwka::ErrorHandlers::NackAndRequeueOnce
        end
      else
        index = error_handling_chain.index(Pwwka::ErrorHandlers::NackAndRequeueOnce)
        if index
          @error_handling_chain[index] = Pwwka::ErrorHandlers::NackAndIgnore
        end
      end
    end

    def default_prefetch=(val)
      @default_prefetch = val.nil? ? val : val.to_i
    end

    # Set this if you don't want the payload parsed.  This can be useful is you are expecting a lot of malformed
    # JSON or if you aren't using JSON at all.  Note that currently, setting this to true will prevent all
    # payloads from being logged
    def receive_raw_payload=(val)
      @receive_raw_payload = val
      @payload_parser = nil
    end

    # Returns a proc that, when called with the payload, parses it according to the configuration.
    #
    # By default, this will assume the payload is JSON, parse it, and return a HashWithIndifferentAccess.
    def payload_parser
      @payload_parser ||= if @receive_raw_payload
                            ->(payload) { payload }
                          else
                            ->(payload) {
                              ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(payload))
                            }
                          end
    end

    # True if we should omit the payload from the log
    #
    # ::level_of_message_with_payload the level of the message about to be logged
    def omit_payload_from_log?(level_of_message_with_payload)
      return true if @receive_raw_payload
      Pwwka::Logging::LEVELS[Pwwka.configuration.payload_logging.to_sym] > Pwwka::Logging::LEVELS[level_of_message_with_payload.to_sym]
    end

    private

    def background_jobs
      {
        resque: Pwwka::SendMessageAsyncJob,
        sidekiq: Pwwka::SendMessageAsyncSidekiqJob,
      }
    end
  end
end
