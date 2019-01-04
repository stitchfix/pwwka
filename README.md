# Pwwka


Pronounced "Poo-ka" |ˈpo͞okə|

![Pwwka Legit](http://res.cloudinary.com/stitch-fix/image/upload/c_scale,h_300/v1413580920/pwwka_yuw7hl.png)

---
[![Build Status](https://travis-ci.org/stitchfix/pwwka.svg?branch=add_travis_yml)](https://travis-ci.org/stitchfix/pwwka)

Provides the means to both send and handle messages on an exchange of a RabbitMQ server.  In a sense, this provides the RabbitMQ equivalent
of `Resque.enqueue` and `SomeResqueJob.perform`.

## Set Up

In your `Gemfile`:

```ruby
gem 'pwwka'
```

or `gem install pwwka` if you aren't using a `Gemfile`.

To run applications locally, you will need Rabbit installed.  The [installation guide](https://www.rabbitmq.com/download.html) is a great
place to start.  This repo includes a `docker-compose.yml` file which will run Rabbit inside a Docker container.  It's used by the tests,
but you can use that, too.

### Configuration

Somewhere in your app, run the following code (in Rails, this would be `config/initializers/pwwka.rb`):

```ruby
require 'pwwka'
Pwwka.configure do |config|
  config.rabbit_mq_host        = ENV['RABBITMQ_URL']
  config.topic_exchange_name   = "mycompany-topics-#{Rails.env}"
  config.delayed_exchange_name = "mycompany-topics-#{Rails.env}"
  config.options               = {allow_delayed: true}
  config.requeue_on_error      = true
  config.default_prefetch      = 10
end
```

Note that the absence of `RABBITMQ_URL` in your environment will cause the underlying RabbitMQ library to use the defaults.  If you aren't
using the defaults, set that environment variable to something like this:

```
amqp://«user»:«password»@«host»:«port»/«vhost»
```

The defaults should be `amqp://guest:guest@localhost:5672/`, i.e.:

* user: guest
* password: guest
* host: localhost
* port: 5672
* vhost: `/`

## Setting it up

### Install RabbitMQ locally

```
brew install rabbitmq
```

And follow the instructions.

### Adding it to your app

Add to your `Gemfile`:

```ruby
gem 'pwwka'
```

## Using Pwwka

Pwwka provides the ability to send a message into Rabbit as well a the ability to receive/handle a message.  Your app can do both of these
things if it needs to.


### Sending a message

You can send any kind of message using `Pwwka::Transmitter.send_message!`:

```ruby
payload = {client_id: '13452564'}
routing_key	= 'sf.clients.client.created'
Pwwka::Transmitter.send_message!(payload, routing_key)
```

The payload should be a simple hash containing primitives. Don't send objects because the payload will be converted to JSON for sending.

#### AMQP Attributes

By default, pwwka will set the following [AMQP Attributes](http://stackoverflow.com/questions/18403623/rabbitmq-amqp-basicproperties-builder-values/18447385#18447385):

* `message_id` - a GUID
* `timestamp` - The time the message is sent
* `app_id` - the name of your Rails app or, if you aren't using rails, the value of `app_id` given to the configuration
* `content_type` - `application/json; version=1`

You may optionally set the following when sending a message to set these additional attributes:

* `message_id` - to override the GUID.  Generally don't do this.
* `type` - a String to define the data type you are sending.  Useful for languages with static types to know how to
deserialize.  You should ensure that the combo of `app_id` and `type` are unique to your entire ecosystem or consumers won't
know what they are receiving.
* `headers` - a hash of arbitrary headers.

A fuller example:

```ruby
Pwwka::Transmitter.send_message!(
  { "customer_id" => 12345, "active" => true },
  "customers.customer.created",
  type: "Customer",
  headers: {
    "RAILS_VERSION" => "5.1.1"
  }
)
```

#### Error Handling

`Pwwka::Transmitter.send_message!` accepts several strategies for handling errors, passed in using the `on_error` parameter:

  * `:raise` - Log the error and raise the exception received from Bunny. (default strategy)
  * `:ignore` - Log the error and return false.
  * `:resque` - Log the error and return false. Also, enqueue a job with Resque to send the message. See `send_message_async` below. **Note, this doesn't guarantee the message will actually be sent—it just guarantees an attempt is made to queue a Resque job [which could fail]**
  * `:sidekiq` - Log the error and return false. Also, enqueue a job with Sidekiw to send the message. See `send_message_async_sidekiq` below. **Note, this doesn't guarantee the message will actually be sent—it just guarantees an attempt is made to queue a Sidekiq job [which could fail]**. To use this option, you will need to configure Pwwka to use the Sidekiq job for async messaging sending (as opposed to the default Resque job):

  ```
  Pwwka.configure do |config|
    config.async_job_klass = Pwwka::SendMessageAsyncSidekiqJob
  end
  ```

Example usage:

```ruby
payload = {client_id: '13452564'}
routing_key	= 'sf.clients.client.created'
Pwwka::Transmitter.send_message!(payload, routing_key, on_error: :ignore)
```


#### Delayed Messages

You might want to delay sending a message (for example, if you have just created a database 
record and a race condition keeps catching you out). In that case you can use delayed message 
options:

```ruby
payload = {client_id: '13452564'}
routing_key	= 'sf.clients.client.created'
Pwwka::Transmitter.send_message!(payload, routing_key, delayed: true, delay_by: 3000)
```

`delay_by` is an integer of milliseconds to delay the message. The default (if no value is set) is 5000 (5 seconds).

These extra arguments work for all message sending methods - the safe ones, the handling, and the `message_queuer` methods (see below).


#### Sending message Async with Resque

To enqueue a message in a background Resque job, use `Transmitter.send_message_async` 
```ruby
Pwwka::Transmitter.send_message_async(payload, routing_key, delay_by_ms: 5000) # default delay is 0
```

If `Resque::Plugins::ExponentialBackoff` is available, the job will use it. (Important: Your load/require order is important if you want exponential backoff with the built-in job due to [its error handling](https://github.com/stitchfix/pwwka/blob/713c6003fa6cf52cb4713c02b39fe7ee07ebe2e9/lib/pwwka/send_message_async_job.rb#L8).)
Customize the backoff intervals using the configuration `send_message_resque_backoff_strategy`.
The default backoff will retry quickly in case of an intermittent glitch, and then every ten 
minutes for half an hour.

The name of the queue created is `pwwka_send_message_async`.

You can configure Pwwka to use your own custom job using the `async_job_klass` configuration option. Example might be:

```
Pwwka.configure do |config|
  config.async_job_klass = YourApp::PwwkaAsyncJob
end
```

#### Sending message Async with Sidekiq

To enqueue a message in a background Sidekiq job, use `Transmitter.send_message_async_sidekiq`
```ruby
Pwwka::Transmitter.send_message_async_sidekiq(payload, routing_key, delay_by_ms: 5000) # default delay is 0
```

To use this, you will need to configure Pwwka to use the Sidekiq job for async messaging sending (as opposed to the default Resque job):

```
Pwwka.configure do |config|
  config.async_job_klass = Pwwka::SendMessageAsyncSidekiqJob # you can also pass in a custom job here
end
```

The name of the queue created is `pwwka_send_message_async`.


#### Message Queuer

You can queue up messages and send them in a batch. This is most useful when multiple messages 
need to sent from within a transaction block.

For example:

```ruby
# instantiate a message_queuer object
message_queuer  = MessageQueuerService.new
ActiveRecord::Base.transaction do
  # do a thing, then queue message
  message_queuer.queue_message(payload: {this: 'that'}, routing_key: 'go.to.there')

  # do another thing, then queue a delayed message
  message_queuer.queue_message(payload: {the: 'other'}, routing_key: 'go.somewhere.else', delayed: true, delay_by: 3000)
end
# send the queued messages if we make it out of the transaction alive
message_queuer.send_messages_safely
```

### Receiving messages

The message-handler comes with a rake task you can use (e.g. in your Procfile) to start up your message handler worker:

```ruby
message_handler: rake message_handler:receive HANDLER_KLASS=ClientIndexMessageHandler QUEUE_NAME=adminapp_style_index ROUTING_KEY='client.#.updated'
```

It requires some environment variables to work:

* `HANDLER_KLASS` (required) refers to the class you have to write in your app (equivalent to a `job` in Resque)
* `QUEUE_NAME` (required) we must use named queues - see below
* `ROUTING_KEY` (optional) comma separated list of routing keys (e.g. `foo.bar.*,foo.baz.*`).  defaults to `#.#` (all messages)
* `PREFETCH` (optional) sets a [prefetch value](http://rubybunny.info/articles/queues.html#qos__prefetching_messages) for the subscriber

You'll also need to bring the Rake task into your app.  For Rails, you'll need to edit the top-level `Rakefile`:

```ruby
require 'pwwka/tasks'
```

#### Queues - what messages will your queue receive

It depends on your `routing_key`. If you set your routing key to `#.#` (the default) it will receive all the messages. The `#` is a wildcard so if you set it to `client.#` it will receive any message with `client.` at the beginning. The exchange registers the queue's name and routing key so it knows what messages the queue is supposed to receive. A named queue will receive each message it expects to get once and only once.

The available wildcards are as follows (and are not intuitive):
* `*` (star) can substitute for **exactly one word**.
* `#` (hash) can substitute for zero or more words.

__A note on re-queuing:__ At the moment messages that raise an error on receipt are marked 'not acknowledged, don't resend', and the failure message is logged. You can configure a single retry by setting the configuration option `requeue_on_error`.  Note that all unacknowledged messages will be resent when the worker is restarted.

__Spinning up some more handlers to handle the load:__ Since each named queue will receive each message only once you can spin up multiple process using the *same named queue* and they will share the messages between them. If you spin up three processes each will receive roughly one third of the messages, but each message will still only be received once.

#### Handlers - The class that handles received messages

Handlers are simple classes that must respond to `self.handle!`. The receiver will send the handler three arguments:

* `delivery_info` - [a bunch of stuff](http://rubybunny.info/articles/queues.html#accessing_message_delivery_information)
* `properties` - [a bunch of other stuff](http://rubybunny.info/articles/queues.html#accessing_message_properties_metadata)
* `payload` - the hash sent by the transmitter

Here is an example:

```ruby
class ClientIndexMessageHandler
  
  def self.handle!(delivery_info, properties, payload)
    handler.do_a_thing(payload)
  end

private

  def self.do_a_thing(payload)
    ###
    # some stuff that is being done
    ###
  end

end
```

#### Payload Parsing

By default, payloads are assumed to be JSON and are parsed before being sent to your `handle!` method (meaning: that method is
given a `HashWithIndifferentAccess` of your payload).

If you don't want this, for example if you are using XML or some other format, you can turn this feature off in your
initializers:

```ruby
# config/initialisers/pwwka.rb
require 'pwwka'

Pwwka.configure do |config|
  config.receive_raw_payload = true
  # any other settings you might have
end
```

In this case, your handler gets whatever Bunny returns, so you are on your own.

#### Errors From Your Handler

By default, handlers will log and ignore garbled payloads (basically payloads that fail to be parsed as JSON).  All other errors
will crash the handler, under the assumption that it will restart.  This is good, because it allows you to recover from most intermittent things.  Just be aware of this when configuring your handler so that it gets restarted after a crash.

What happens to the message you received during the error depends:

* If the error is not a `StandardError` or a subclass, the message will not be ack'ed and will be waiting on the queue for you when you next fetch a message
* If the errors *is* a `StandardError` or a subclass, the message will be ack'ed and removed from the queue.
  - By default, the message is not re-queued and is essentially dropped on the floor.  Its payload is logged, so you can recover that way.
  - If you set `requeue_on_error = true` in your Pwwka configuration, a message gets requeued **exactly once** on failure.  If the message involved in the failure has been redelivered before, it's dropped on the floor.  This behavior allows you to recover from most intermittent failures, like so:
    1. You receive message for the first time.
    1. Intermittent failure (e.g. network problem) happens, and an exception is raised.
    1. Pwwka catches this exception and requeues the message.
    1. Pwwka then crashes your handler.
    1. Your handler restarts.
    1. The message is in the queue, waiting for you.
    1. You handle it. (*if you error here, the message is not requeued*)

The reason we don't always requeue on error is that a hard failure would result in an infinite loop.  The reason we don't use the dead letter exchange is that there is no way in the Rabbit console to deal with
these messages.  Some day Pwwka might have code to allow that.  Today is not that day.

**You should configure `requeue_on_error`**. It's not the default for backwards compatibility.

#### Advanced Error Handling

The underlying implementation of how errors are handled is via a [chain of responsibility-ish](https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern) implementation.  When an unhandled exception occurs, pwwka's `Receiver`
defers to the configurations `error_handling_chain`, which is a list of classes that can handle errors.  `requeue_on_error` and `keep_alive_on_handler_klass_exceptions` control which classes are in the chain.

If you want to handle errors differently, for example crashing on some exceptions, but not others, or requeing messages on failures always (instead of just once), you can do that by subclassing `Pwwka::ErrorHandlers::BaseHandler`.
It defines a method `handle_error` that is given the `Receiver` instance, queue name, payload, delivery info, and the uncaught exception.  If the method returns `true`, Pwwka calls the remaining handlers.  If false, it stops processing.

Your subclass can be inserted into the chain in two ways.  Way #1 is to override the entire chain by setting `Pwwka.configuration.error_handling_chain` to an array of handlers, including yours.  Way #2 is to have your specific
message handler implement `self.error_handler` to return the class to be used for just that message handler.

**When you do this**, be careful to ensure you ack or nack.  If you fail to do either, your messages will build up and bad things will happen.

For example, suppose you want to catch an ActiveRecord error, unwrap it to see if it's a problem with the connection, and reconnect before trying again.

First, implement your custom error handler:

```ruby
class PostgresReconnectHandler < Pwwka::ErrorHandlers::BaseHandler
  def handle_error(receiver,queue_name,payload,delivery_info,exception)
    if exception.cause.is_a?(PG::ConnectionBad)
      ActiveRecord::Base.connection.reconnect!
    end
    keep_going
  end
end
```

In your pwwka initializer:

```ruby
require 'pwwka'
Pwwka.configure do |config|
  config.rabbit_mq_host        = ENV['RABBITMQ_URL']
  config.topic_exchange_name   = "mycompany-topics-#{Rails.env}"
  config.delayed_exchange_name = "mycompany-topics-#{Rails.env}"
  config.options               = {allow_delayed: true}
  config.error_handling_chain = [
    PostgresReconnectHandler,
    Pwwka::ErrorHandlers::NackAndRequeueOnce,
    Pwwka::ErrorHandlers::Crash
  ]
end
```

This says:

* If the error was a `PG::ConnectionBad`, reconnect
* If the message has not been retried, nack it and requeue it, otherwise ignore it (`NackAndRequeueOnce`)
* Crash the handler

You might not want to crash the handler in the case of `PG::ConnectionBad`.  And, you might want to always retry the job, even if it's been retried before so you don't lose it.

In that case, your handler could work like this:


```ruby
class PostgresReconnectHandler < Pwwka::ErrorHandlers::BaseHandler
  def handle_error(receiver,queue_name,payload,delivery_info,exception)
    if exception.cause.is_a?(PG::ConnectionBad)
      ActiveRecord::Base.connection.reconnect!
      log("Retrying an Error Processing Message",queue_name,payload,delivery_info,exception)
      receiver.nack_requeue(delivery_info.delivery_tag)
      abort_chain
    else
      keep_going
    end
  end
end
```

Now, if we get a `PG::ConnectionBad`, we reconnect, nack with requeue and stop processing the error (`abort_chain` is an alias for `false`, and `keep_going` is an alias for `true`, but they keep you from having to remember what to return).

**When making your own handlers** it's important to make sure that the message is nacked or acked.**

#### Handling Messages with Resque

If you use [Resque][resque], and you wish to handle messages in a resque job, you can use `Pwwka::QueueResqueJobHandler`, which is an adapter between the standard `handle!` method provided by pwwka and your Resque job.

1. First, modify your `Gemfile` or otherwise arrange to include `pwwka/queue_resque_job_handler`:

   ```ruby
   gem 'pwwka', require: [ 'pwwka', 'pwwka/queue_resque_job_handler' ]
   ```

   or, in `config/initializers/pwwka.rb`:

   ```ruby
   require 'pwwka/queue_resque_job_handler'
   ```

2. Now, configure your handler.  For a `Procfile` setup:

   ```
   my_handler: rake message_handler:receive HANDLER_KLASS=Pwwka::QueueResqueJobHandler JOB_KLASS=MyResqueJob QUEUE_NAME=my_queue ROUTING_KEY="my.key.completed"
   ```

   Note the use of the environment variable `JOB_KLASS`.  This tells `QueueResqueJobHandler` which class to queue.
3. Now, write your job.

   ```ruby
   class MyResqueJob
     @queue = :my_resque_queue

     def self.perform(payload,            # the payload
                      routing_key,        # routing key as a string
                      message_properties) # properties as a hash with _String_ keys
       user = User.find(payload.fetch("user_id")) # or whatever
       user.frobnosticate!
     end
   end
   ```

   Note that you must provide `@queue` in your job.  `QueueResqueJobHandler` doesn't support setting a custom queue at enqueue-time (PRs welcome :).

   Note that if you were using this library before version 0.12.0, your job would only be given the payload.  If you change your job to accept exatly three arguments, you will be given the payload, routing key, and message properties.  If any of those arguments are optional, you will need to set `PWWKA_QUEUE_EXTENDED_INFO` to `"true"` to force pwwka to pass those along.  Without it, your job only gets the payload to avoid breaking legacy consumers. 

3. Profit!

[resque]: https://github.com/resque/resque/tree/1-x-stable

### Testing

This gem has test coverage of interacting with RabbitMQ, so for unit tests, your best
strategy is to simply mock calls to `Pwwka::Transmitter`.

For integration tests, however, you can examine the actual message bus by setting up
the provided `Pwwka::TestHandler` like so:

```ruby
require 'pwwka/test_handler'

describe "my integration test" do

  before(:all) do
    @test_handler = Pwwka::TestHandler.new
    @test_handler.test_setup
  end

  after(:all) do 
    # this clears out any messages, so you have a clean test environment next time
    @test_handler.test_teardown 
  end

  it "uses the message bus" do
    post "/items", item: { size: "L" }

    message = @test_handler.pop_message

    expect(message.delivery_info.routing_key).to eq("my-company.items.created")
    expect(message.payload).to eq({ item: { id: 42, size: "L" } })
  end

  it "can splat the values as well" do
    post "/items", item: { size: "L" }

    delivery_info, payload = @test_handler.pop_message

    expect(delivery_info.routing_key).to eq("my-company.items.created")
    expect(payload).to eq({ item: { id: 42, size: "L" } })
  end
end
```

[See CONTRIBUTING.md for details on testing this gem](CONTRIBUTING.md#testing)


## Better Know a Message Bus

If you aren't familiar with Rabbit or Message Busses, the idea is that messages can be sent “into the ether” with no particular
destination.  Subscribers can listen for those messages and choose to respond.

For example, suppose a customer purchases an order.  The app serving our public website sends a message that this has happened.  Another
app that sends emails will hear that message, and use it to trigger a receipt email to the customer.  A yet other app that does financial
reporting might hear this same message and record the sale to the company's ledger.  The app serving our public website doesn't know about
any of these things.

### How Pwwka Uses Rabbit

All transmitters and receivers share the same exchange. This means that all receivers can read all messages that any transmitter sends. To ensure that all messages are received by eveyone who wants them the Pwwka configures everything as follows:

* The exchange is named and durable. If the service goes down and restarts the named exchange will return with the same settings so everyone can reconnect.
* The receiver queues are all named and durable. If the service goes down and restarts the named queue will return with the same settings so everyone can reconnect, and with any unacknowledged messages waiting to be received.
* All messages are sent as persistent and require acknowledgement. They will stick around and wait to be received and acknowledged by every queue that wants them, regardless of service interruptions.


### Monitoring

RabbitMQ has a good API that should make it easy to set up some simple monitoring. In the meantime there is logging and manual monitoring.

#### Logging

The receiver logs details of any exception raised in message handling:

```ruby
error "Error Processing Message on #{queue_name} -> #{payload}, #{delivery_info.routing_key}: #{e}"
```

The transmitter will likewise log an error if you use the `_safely` methods:

```ruby
error "Error Transmitting Message on #{routing_key} -> #{payload}: #{e}"
```

If your payloads are large, you may not want to log them 2-3 times per message.  In that case, you can adjust `payload_logging` in the configuration:

```ruby
Pwwka.configuration.payload_logging = :info # The default - payloads appear at INFO and above log levels
Pwwka.configuration.payload_logging = :error # Only log payloads for ERROR or FATAL messages
Pwwka.configuration.payload_logging = :fatal # Only log payloads for FATAL messages
```

#### Manual monitoring

RabbitMQ has a web interface for checking out the health of connections, channels, exchanges and queues. Your RabbitMQ provider should
provide a link.  If you are running Rabbit locally, the management interface is on port 15672 by default (or port 10002 if using the included `docker-compose.yml`).  The user is "guest" and the password is "guest".

![RabbitMQ Management 1](docs/images/RabbitMQ_Management.png)
![RabbitMQ Management 2](docs/images/RabbitMQ_Management-2.png)
![RabbitMQ Management 3](docs/images/RabbitMQ_Management-3.png)

## Contributing

We're actively using Pwwka in production here at [Stitch Fix](http://technology.stitchfix.com/) and look forward to seeing Pwwka grow and improve with your help. Contributions are warmly welcomed.

[See CONTRIBUTING.md for details](CONTRIBUTING.md)

## Licence

Pwwka is released under the [MIT License](http://www.opensource.org/licenses/MIT).

