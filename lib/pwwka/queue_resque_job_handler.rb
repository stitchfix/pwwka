require 'active_support/core_ext/string/inflections'
require 'resque'

module Pwwka
  # A handler that simply queues the payload into a Resque job.  This is useful
  # if the code that should respond to a message needs to be managed by Resque, e.g.
  # for the purposes of retry or better failure management.  You can ask for the routing key and properties
  # by setting `PWWKA_QUEUE_EXTENDED_INFO` to `true` in your environment.
  #
  # You should be able to use this directly from your handler configuration, e.g. for a Heroku-style `Procfile`:
  #
  #     my_handler: rake message_handler:receive HANDLER_KLASS=Pwwka::QueueResqueJobHandler JOB_KLASS=MyResqueJob QUEUE_NAME=my_queue ROUTING_KEY="my.key.completed"
  #     my_handler_that_wants_more_info: rake message_handler:receive HANDLER_KLASS=Pwwka::QueueResqueJobHandler JOB_KLASS=MyOthgerResqueJob PWWKA_QUEUE_EXTENDED_INFO=true QUEUE_NAME=my_queue ROUTING_KEY="my.key.#"
  #
  # Note that this will not check the routing key, so you should be sure to specify the most precise ROUTING_KEY you can for handling the message.
  class QueueResqueJobHandler
    def self.handle!(delivery_info,properties,payload)
      args = [
        ENV["JOB_KLASS"].constantize,
        payload
      ]
      if ENV["PWWKA_QUEUE_EXTENDED_INFO"] == 'true'
        args << delivery_info.routing_key
        args << properties.to_hash
      end
      Resque.enqueue(*args)
    end
  end
end
