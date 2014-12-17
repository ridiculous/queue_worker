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

    worker = QueueWorker.new('some_queue_name')
    worker.push({ name: 'foo' })
    worker.handler = proc { |args| puts "Got #{args}" }
    worker.subscribe

## Contributing

1. Fork it ( https://github.com/ridiculous/queue_worker/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
