class IntegrationTestSetup

  def threads
    @threads ||= {}
  end

  def channels
    @channels ||= []
  end

  def make_queue_and_setup_receiver(klass,queue_name,routing_key)
    channel_connector = Pwwka::ChannelConnector.new(queue_name: queue_name)
    channel_connector.bind(routing_key: routing_key)
    channels << channel_connector
    threads[klass] = Thread.new do
      Pwwka::Receiver.subscribe(klass, queue_name, routing_key: routing_key)
    end
  end

  def kill_threads_and_clear_queues
    threads.each do |_,thread|
      Thread.kill(thread)
    end
    channels.each do |channel|
      channel.purge
      channel.delete
    end
  end

end
