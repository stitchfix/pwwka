GEM_ROOT = File.expand_path(File.join(File.dirname(__FILE__),'..'))
require 'pwwka'
require 'pwwka/test_handler'
Dir["#{GEM_ROOT}/spec/support/**/*.rb"].sort.each {|f| require f}

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

end

Pwwka.configure do |config|
  config.topic_exchange_name  = "topics-test"
  config.logger               = MonoLogger.new("/dev/null")
end
