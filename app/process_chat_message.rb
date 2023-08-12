require 'json'

$LOAD_PATH.unshift('./lib/')
require 'babulus'

def handle_aws_lambda_event_for_queued_chat_message(event:, context:)
  $logger.debug("Received event from Lambda:\n#{JSON.pretty_generate(event)}")

  event['Records'].each do |record|
    $logger.debug("Processing SQS message:\n#{JSON.pretty_generate(record)}")
    Babulus::SlackEventsAPIHandler.new(record['body']).dispatch
  end

  {
    statusCode: 200,
    body: 'Message(s) processed.'
  }
end