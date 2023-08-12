$LOAD_PATH.unshift File.expand_path('./lib/', __dir__)
require 'babulus/spec_helper'
require_relative 'process_chat_message'

module Babulus

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

    handle_aws_lambda_event(event: lambda_event, context: {})
  end
end

end # module Babulus