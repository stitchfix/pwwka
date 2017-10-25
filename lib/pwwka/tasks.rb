namespace :message_handler do
  desc "Start the message bus receiver"
  task :receive => :environment do
    raise "HANDLER_KLASS must be set" unless ENV['HANDLER_KLASS']
    raise "QUEUE_NAME must be set" unless ENV['QUEUE_NAME']
    handler_klass = ENV['HANDLER_KLASS'].constantize
    queue_name    = "#{ENV['QUEUE_NAME']}_#{Rails.env}"
    routing_key   = ENV['ROUTING_KEY'] || "#.#"
    Pwwka.configuration.prefetch = ENV['PREFETCH'] if ENV.has_key?('PREFETCH')

    Pwwka::Receiver.subscribe(handler_klass, queue_name, routing_key: routing_key)
  end
end
