require 'spec_helper'

describe QueueWorker, slow: true do
  let(:queue_name) { 'queue_foo' }
  let(:log) { Logger.new(STDOUT).tap { |x| x.level = Logger::ERROR } }
  let(:message) { Struct.new(:command, :body).new('MESSAGE', '{}') }

  subject { described_class.new(queue_name, log) }

  before { allow(subject).to receive(:client).and_return(double(Stomp::Client)) }

  describe '.publish' do
    let(:message) { { id: 101 } }
    let(:worker) { double('Worker') }

    it 'publishes the messages to an instance of itself' do
      expect(described_class).to receive(:new).with(queue_name).and_return(worker)
      expect(worker).to receive(:close)
      expect(worker).to receive(:publish).with(message)
      described_class.publish(queue_name, message)
    end
  end

  describe '.subscribe' do
    let(:handler) { proc {} }

    it 'instantiates and subscribes itself to a given queue' do
      expect(described_class).to receive(:new).with(queue_name, log, &handler).and_return(subject)
      expect(subject).to receive(:subscribe)
      expect(subject).to receive(:join)
      described_class.subscribe(queue_name, log, &handler)
    end
  end

  describe '#publish' do
    let(:message) { {} }

    before(:each) { allow(subject.client).to receive(:publish) }

    context 'unless the message is a string' do
      it "converts the message argument to json" do
        expect(message).to receive(:to_json)
        subject.publish(message)
      end
    end

    it 'merges in default headers and publishes the message to the client' do
      expect(subject.client).to receive(:publish).with("/queue/#{queue_name}", message.to_json, priority: 6, persistent: true)
      # priority defaults to 4, so we override it here
      subject.publish(message, priority: 6)
    end
  end

  describe '#subscribe' do
    let(:size) { 1 }
    let(:headers) { { :ack => 'client', 'activemq.prefetchSize' => size } }

    it 'pass the -message- to +call+' do
      expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
      expect(subject).to receive(:call).with(message)
      subject.subscribe
    end

    context 'when -queue_name- is given' do
      it 'subscribes to the specified queue' do
        expect(subject.client).to receive(:subscribe).with("/queue/test", headers).and_yield(message)
        expect(subject).to receive(:call).with(message)
        subject.subscribe('test')
      end
    end

    context 'when -size- is given' do
      let(:size) { 5 }

      it 'fetches the specified number of messages' do
        expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
        expect(subject).to receive(:call).with(message)
        subject.subscribe(nil, size)
      end
    end

    context 'when a block is given' do
      let(:handler_double) { double('Handler block') }

      it 'yields the given block instead of calling +call+' do
        expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
        expect(handler_double).to receive(:call).with(message)
        expect(subject).to_not receive(:call)
        subject.subscribe { |message| handler_double.call(message) }
      end
    end
  end

  describe '#unsubscribe' do
    it 'calls +unsubscribe+ on the client with the given queue' do
      expect(subject.client).to receive(:unsubscribe).with("/queue/#{queue_name}")
      subject.unsubscribe
    end
  end

  describe '#call' do
    let(:message) { double("Stomp::Message", body: %({"class":"QueueWorker", "args": [101]}), command: 'MESSAGE', headers: { 'destination' => '/queue/null' }) }

    context "when message command is 'MESSAGE'" do
      it 'acknowledges the message and passes it along to the handler' do
        expect(subject.handler).to receive(:call).with({ class: 'QueueWorker', args: [101] }, message)
        expect(subject).to receive(:ack).with(message)
        subject.call(message)
      end
    end

    context "when message command is not 'MESSAGE'" do
      let(:message) { Struct.new(:command).new('PING') }

      it 'does nothing' do
        expect(subject.handler).to_not receive(:call)
        expect(subject).to receive(:ack).with(message)
        subject.call(message)
      end
    end

    context 'default handler' do
      it 'loads the :class and calls it with the message body' do
        expect(QueueWorker).to receive(:call).with([101])
        subject.handler.call(JSON.parse(message.body, symbolize_names: true))
      end
    end
  end

  describe '#quit' do
    it 'unsubscribes from the current queue and closes the connection' do
      expect(subject).to receive(:unsubscribe)
      expect(subject).to receive(:close)
      subject.quit
    end
  end
end
