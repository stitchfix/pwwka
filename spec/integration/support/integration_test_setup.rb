class IntegrationTestSetup

  def threads
    @threads ||= {}
  end

  def queues
    @queues ||= []
  end

  def make_queue_and_setup_receiver(klass,queue_name,routing_key)
    queue = channel.queue(queue_name, durable: true, arguments: {})
    queue.bind(topic_exchange, routing_key: routing_key)
    queues << queue
    threads[klass] = Thread.new do
      Pwwka::Receiver.subscribe(klass, queue_name, routing_key: routing_key)
    end
  end

  def kill_threads_and_clear_queues
    threads.each do |_,thread|
      Thread.kill(thread)
    end
    queues.each do |queue|
      queue.purge
      queue.delete
    end
  end

  def channel_connector
    @channel_connector ||= Pwwka::ChannelConnector.new
  end

  def channel
    channel_connector.send(:channel)
  end

  def topic_exchange
    channel_connector.send(:topic_exchange)
  end

end
