require 'rspec'
require 'aws-sdk-sqs'
require_relative 'api_gateway'

describe 'lambda_handler' do
  let(:logger) { Logger.new(STDOUT) }
  let(:sqs_client) { instance_double(Aws::SQS::Client) }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
  end

  context 'when event type is url_verification' do
    let(:event) do
      {
        'body' => {
          'type' => 'url_verification',
          'challenge' => 'test_challenge'
        }.to_json
      }
    end

    it 'responds with url confirmation' do
      allow(logger).to receive(:info)
      expect(logger).to receive(:info).with(/URL verification/)
      response = api_gateway_lambda_handler(event: event, context: {})
      expect(response).to eq({
        statusCode: 200,
        body: 'test_challenge'
      })
    end
  end

  context 'when event type is message' do
    let(:event) do
      {
        'body' => {
          'type' => 'message',
          'text' => 'Hello'
        }.to_json
      }
    end

    before do
      allow(sqs_client).to receive(:send_message).and_return(true)
    end

    it 'responds with Message received' do
      allow(logger).to receive(:info)
      expect(logger).to receive(:info).with(/Enqueing SQS message/)
      response = api_gateway_lambda_handler(event: event, context: {})
      expect(response).to eq({
        statusCode: 200,
        body: 'Message received.'
      })
    end

    it 'enqueues message for processing' do
      expect(sqs_client).to receive(:send_message).with({
        queue_url: ENV['SQS_QUEUE_URL'],
        message_body: event['body']
      })
      api_gateway_lambda_handler(event: event, context: {})
    end
  end
end
