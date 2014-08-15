require 'bunny'
require 'mono_logger'
module Pwwka
  class Configuration

    attr_accessor :rabbit_mq_host 
    attr_accessor :topic_exchange_name
    attr_accessor :logger
    attr_accessor :options

    def initialize
      @rabbit_mq_host       = nil
      @topic_exchange_name  = "pwwka-topics-#{Pwwka.environment}"
      @logger               = MonoLogger.new(STDOUT)
      @options              = {}
    end

  end
end
