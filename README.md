# QueueWorker

A light STOMP wrapper to ease interaction with a queueing system (e.g. ActiveMQ)

## Installation

Add this line to your application's Gemfile:

    gem 'queue_worker'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install queue_worker

## Usage
```ruby
worker = QueueWorker.new('some_queue_name')
# Publish a message (will be serialized to JSON)
worker.push({ name: 'foo' }) 
# Specify the subscribe callback (message is automatically deserialized and ack'd)
worker.handler = proc { |args| puts "Got message #{args}" }
# Asynchronously subscribe to the queue
worker.subscribe 
```
Wait (synchronously) for a message to be received and acknowledged (ack'd) before continuing    
```ruby
worker.join
```
Remove the listener (thread) and closes the connection
```ruby
worker.close
```
Alternatively, a block can be given to `subscribe` and the number of messages to fetch can be specified (default 1).
```ruby
worker.subscribe(10) do |message|
  if message.command == 'MESSAGE'
    puts "Got message #{JSON.parse(message.body, symbolize_names: true)}"
  end
  worker.ack(message)
end
```
## Contributing

1. Fork it ( https://github.com/ridiculous/queue_worker/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
