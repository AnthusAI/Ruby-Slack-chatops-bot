require_relative 'sqs_message_processor'
require_relative 'lib/slack_events_api'

describe 'SlackEventsAPIHandler' do
  let(:event_body) do
    {
      'token' => 'Jhj5dZrVaK7ZwHHjRyZWjbDl',
      'challenge' => '3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P',
      'type' => 'url_verification'
    }.to_json
  end
  let(:lambda_event) do
    {
      'Records' => [
        {
          'body' => event_body
        }
      ]
    }
  end

  it 'creates a SlackEventsAPIHandler object and calls dispatch on it' do
    slack_event = instance_double('SlackEventsAPIHandler')

    allow(SlackEventsAPIHandler).to receive(:new).with(event_body).
      and_return(slack_event)
    expect(slack_event).to receive(:dispatch)

    sqs_message_processor_lambda_handler(event: lambda_event, context: {})
  end
end
