GEM_ROOT = File.expand_path(File.join(File.dirname(__FILE__),'..'))

ENV['RAILS_ENV']  ||= 'test'

require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
end

require 'pwwka'
require 'pwwka/test_handler'
require 'active_support/core_ext/hash'

# These are required in pwwka proper, but they are guarded to not cause
# an error if missing.  Requiring here so their absence will fail the tests
require 'resque'
require 'resque-retry'

require 'support/test_configuration'

test_configuration = TestConfiguration.new(File.join(GEM_ROOT,"docker-compose.yml"))

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = [:should,:expect] # should is needed to make a resque helper 
                                 # from resqutils work
  end

  config.before(:suite) do
    Pwwka.configure do |c|
      c.topic_exchange_name        = "topics-test"
      c.options[:allow_delayed]    = true
      c.requeue_on_error           = false
      c.rabbit_mq_host             = "amqp://guest:guest@localhost:#{test_configuration.rabbit_port}"
      c.app_id                     = "MyAwesomeApp"

      unless ENV["SHOW_PWWKA_LOG"] == "true"
        c.logger = MonoLogger.new("/dev/null")
      end
    end
    Resque.redis = Redis.new(port: test_configuration.resque_redis_port)
  end
  config.around(:each) do |example|
    if example.metadata[:integration]
      result = test_configuration.check_services
      unless result.up?
        fail result.error
      end
    end
    example.run
    Pwwka.configuration.receive_raw_payload = false
  end
  config.order = :random
  config.filter_run_excluding :legacy
end

