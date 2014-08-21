require 'bunny'
require 'mono_logger'
module Pwwka
  class Configuration

    attr_accessor :rabbit_mq_host 
    attr_accessor :topic_exchange_name
    attr_accessor :logger
    attr_accessor :allow_retry
    attr_accessor :redis_server
    attr_accessor :options

    def initialize
      @rabbit_mq_host       = nil
      @topic_exchange_name  = "pwwka-topics-#{Pwwka.environment}"
      @logger               = MonoLogger.new(STDOUT)
      # Retrying
      @allow_retry          = false
      @redis_server         = nil
      @options              = {}
    end

  end
end
