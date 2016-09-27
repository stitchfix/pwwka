GEM_ROOT = File.expand_path(File.join(File.dirname(__FILE__),'..'))
ENV['RAILS_ENV']  ||= 'test'
require 'pwwka'
require 'pwwka/test_handler'
Dir["#{GEM_ROOT}/spec/support/**/*.rb"].sort.each {|f| require f}

RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all) do
    Pwwka.configure do |c|
      c.topic_exchange_name     = "topics-test"
      c.logger                  = MonoLogger.new("/dev/null")
      c.options[:allow_delayed] = true
    end
  end

end

