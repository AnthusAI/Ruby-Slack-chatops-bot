require 'json'
require_relative 'slack_events_api'

def lambda_handler(event:, context:)
  # Instantiate SlackEventsAPI object and call dispatch on it.
  slack_event = event['body']
  slack_events_api = SlackEventsAPI.new(slack_event)

  {
    statusCode: 200,
    body: slack_events_api.dispatch
  }
end
