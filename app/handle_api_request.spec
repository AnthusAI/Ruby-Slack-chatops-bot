require 'rspec'
require 'aws-sdk-sqs'

$LOAD_PATH.unshift File.expand_path('./lib/', __dir__)
require 'babulus/spec_helper'
require_relative 'handle_api_request'

ENV['AWS_RESOURCE_NAME'] = 'Babulus'

describe 'lambda_handler' do
  let(:logger) { $logger }
  let(:ssm_client) { instance_double(Aws::SSM::Client) }
  let(:sqs_client) { instance_double(Aws::SQS::Client) }
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }
  let(:secretsmanager_client) { instance_double(Aws::SecretsManager::Client) }
  
  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(Aws::SSM::Client).to receive(:new).and_return(ssm_client)
    allow(Aws::SecretsManager::Client).to receive(:new).and_return(secretsmanager_client)
    allow(ssm_client).to receive(:get_parameter).and_return(
      instance_double('Aws::SSM::Types::GetParameterResult',
        parameter: instance_double(
          'Aws::SSM::Types::Parameter', value: 'test_token'
        )
      )
    )
    allow(Aws::SQS::Client).to receive(:new).and_return(sqs_client)
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)

    allow(secretsmanager_client).to receive(:get_secret_value).with(
      secret_id: 'Babulus-slack-app-access-token-development'
    ).and_return(
      instance_double(
        'Aws::SecretsManager::Types::GetSecretValueResponse',
        secret_string: 'DEADBEEF')
    )
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
      response = handle_aws_lambda_event_for_api_request(event: event, context: {})
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to eq('test_challenge')
    end
  end

  context 'when event type is message' do
    let(:event) do
      {
        'body' => {
          'event' => {
            'type' => 'message',
            'text' => 'Hello'
          }
        }.to_json
      }
    end

    before do
      allow(sqs_client).to receive(:send_message).and_return(true)
      allow_any_instance_of(Babulus::SlackEventsAPIHandler).to receive(
        :event_needs_processing?
      ).and_return(true)
    end

    it 'responds with Message received' do
      allow(logger).to receive(:info)
      expect(logger).to receive(:info).with(/Enqueing SQS message/)
      response = handle_aws_lambda_event_for_api_request(event: event, context: {})
      expect(response[:statusCode]).to eq(200)
      expect(response[:body]).to eq('Message received.')
    end

    it 'enqueues message for processing' do
      expect(sqs_client).to receive(:send_message).with(
        hash_including(
          queue_url: ENV['SQS_QUEUE_URL'],
          message_body: event['body'],
          message_group_id: nil
        )
      )
      handle_aws_lambda_event_for_api_request(event: event, context: {})
    end
  end
end
