require_relative 'bot'
require_relative 'slack_events_api'

describe 'Bot' do
  let(:event_body) do
    {
      'token' => 'Jhj5dZrVaK7ZwHHjRyZWjbDl',
      'challenge' => '3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P',
      'type' => 'url_verification'
    }.to_json
  end

  it 'creates a SlackEventsAPIHandler object and calls dispatch on it' do
    slack_event = instance_double('SlackEventsAPIHandler')

    allow(SlackEventsAPIHandler).to receive(:new).with(event_body).and_return(slack_event)
    expect(slack_event).to receive(:dispatch)

    lambda_handler(event: { 'body' => event_body }, context: {})
  end
end
