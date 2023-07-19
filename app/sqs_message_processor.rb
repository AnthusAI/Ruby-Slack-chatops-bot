require 'json'

$LOAD_PATH.unshift('./lib/')
require 'babulus'

def sqs_message_processor_lambda_handler(event:, context:)
  $logger.debug("Received event from Lambda:\n#{JSON.pretty_generate(event)}")

  event['Records'].each do |record|
    $logger.debug("Processing SQS message:\n#{JSON.pretty_generate(record)}")
    SlackEventsAPIHandler.new(record['body']).dispatch
  end

  {
    statusCode: 200,
    body: 'Message(s) processed.'
  }
end
