module Pwwka

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def environment
      ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end   
  end

end

require 'json'
require 'redis'
require 'sucker_punch'
require 'active_support/inflector'
require 'active_support/core_ext/module'
require 'active_support/hash_with_indifferent_access'

require 'pwwka/version'
require 'pwwka/logging'
require 'pwwka/channel_connector'
require 'pwwka/handling'
require 'pwwka/receiver'
require 'pwwka/redis_logger'
require 'pwwka/retry'
require 'pwwka/transmitter'

require 'pwwka/configuration'
