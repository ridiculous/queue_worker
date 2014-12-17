require 'spec_helper'

describe QueueWorker, slow: true do
  let(:queue_name) { 'queue_foo' }

  subject { described_class.new(queue_name, double(Stomp::Client)) }

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
    let(:headers) { { :ack => 'client', 'activemq.prefetchSize' => 1 } }

    context "when message command is not 'MESSAGE'" do
      let(:message) { Struct.new(:command).new('PING') }

      it 'does nothing' do
        expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
        expect(subject).to_not receive(:unsubscribe)
        expect(subject).to_not receive(:call)
        subject.subscribe
      end
    end

    context "when message command is 'MESSAGE'" do
      let(:message) { Struct.new(:command, :body).new('MESSAGE', nil) }

      context "when message body is 'UNSUBSCRIBE'" do
        before { message.body = 'UNSUBSCRIBE' }

        it 'unsubscribes from the -queue-' do
          expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
          expect(subject).to receive(:unsubscribe)
          subject.subscribe
        end
      end

      context "when message body is JSON" do
        before { message.body = '{}' }

        it 'pass the -message- to +call+' do
          expect(subject.client).to receive(:subscribe).with("/queue/#{queue_name}", headers).and_yield(message)
          expect(subject).to receive(:call).with(message)
          subject.subscribe
        end
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
    let(:message) { double("Stomp::Message", body: %({"name":"trip_advisor"}), headers: { 'destination' => '/queue/null' }) }

    it 'acknowledges the message and passes it along to the handler class' do
      expect(subject.handler).to receive(:call).with({ name: 'trip_advisor' }, message)
      expect(subject).to receive(:ack).with(message)
      subject.call(message)
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
