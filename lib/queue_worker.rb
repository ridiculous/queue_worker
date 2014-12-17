require 'json'
require 'logger'
require 'timeout'
require 'forwardable'
require 'stomp'

class QueueWorker

  VERSION = '0.0.1'

  extend Forwardable

  def_delegators :client,
    :ack, :join, :close


  class << self
    attr_accessor :stomp

    def configure
      yield self
    end
  end

  attr_writer :client
  attr_accessor :queue, :handler

  # @param [String] queue_name the queue to pub/sub
  # @param [Stomp::Client] client that can communicate with ActiveMQ
  def initialize(queue_name = nil, client = nil)
    @queue = queue_name
    @client = client
    @handler = proc { |args, message| load_handler_class(message.headers['destination']).new(args).call }
  end

  # = Publish one or more messages to a queue
  #
  # @param [String] queue name
  # @param [Array] messages a list of objects that are or can be converted to JSON
  def self.publish(queue, *messages)
    worker = new(queue)
    messages.each { |msg| worker.publish(msg) }
    worker.close
  end

  # = Peek at any number messages in the queue
  #
  # @param [String] queue_name
  # @param [Integer] size specify the number of messages to return
  def self.peek(queue_name, size = 1)
    counter = 0
    messages = []
    worker = new(queue_name)
    worker.subscribe_with_timeout(2, size) do |message|
      counter += 1
      messages << JSON.parse(message.body).merge('message-id' => message.headers['message-id'])
      worker.quit if counter == size
    end
    messages
  end

  # = Publish a message to a queue
  #
  # @param [Hash] message - Data to serialize
  # @param [Hash] headers - Additional header options for ActiveMQ
  def publish(message, headers = {})
    message = message.to_json unless message.is_a?(String)
    client.publish("/queue/#{queue}", message, { priority: 4, persistent: true }.merge(headers))
  end

  alias push publish

  # = Subscribe (listen) to a queue
  #
  # @param [Integer] size specify the number of messages the block may receive without sending +ack+
  # @param [Proc] block to handle the subscribe callback
  def subscribe(size = 1, &block)
    callback = block || method(:default_subscribe_callback)
    client.subscribe("/queue/#{queue}", { :ack => 'client', 'activemq.prefetchSize' => size }, &callback)
  end

  # = Subscribe to a queue for a limited time
  #
  # @param [Integer] duration to subscribe for before closing connection
  # @param [Integer] size specify the number of messages the block may receive without sending +ack+
  # @param [Proc] block to handle the subscribe callback
  def subscribe_with_timeout(duration, size = 1, &block)
    Timeout::timeout(duration) do
      subscribe(size, &block)
      join
    end
  rescue Timeout::Error
    quit
  end

  # = Unsubscribe from the current queue
  def unsubscribe
    client.unsubscribe("/queue/#{queue}")
  end

  # = Unsubscribe from the current queue and close the connection
  def quit
    unsubscribe
    close
  end

  # = Handles +subscribe+ callback
  #
  # Tries to delegate processing of message to a class based on the name of the queue. For example:
  #
  #   If the queue is named "scheduled/default" it will look for a class called Scheduled::Default to
  #   initialize with the message body and then call it's +call+ method
  #
  # @param [Stomp::Message] message is the container object Stomp gives us for what is really a "frame" or package from the queue
  def call(message)
    handler.call(JSON.parse(message.body, symbolize_names: true), message)
  rescue => e
    log.error(e.message) { "\n#{e.backtrace.inspect}" }
  ensure
    ack(message)
    log.info('Processed') { message }
  end

  #
  # Private
  #

  def default_subscribe_callback(message)
    if message.command == 'MESSAGE'
      if message.body == 'UNSUBSCRIBE'
        unsubscribe
      else
        call(message)
      end
    end
  end

  # = Converts the queue name to a constant
  #
  # @param [String] destination_queue
  #
  def load_handler_class(destination_queue)
    destination_queue.gsub(%r!^/?queue/!, '').camelize.constantize
  end

  def client
    @client ||= Stomp::Client.new(self.class.stomp)
  end

  def log
    @log ||= Logger.new(STDOUT)
  end

end
