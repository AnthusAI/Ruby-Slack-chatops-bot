require 'json'
require 'logger'
require 'awesome_print'
require_relative 'lib/slack_events_api'

def sqs_message_processor_lambda_handler(event:, context:)
  logger = Logger.new(STDOUT)
  logger.info("Received event from Lambda: #{event.ai}")

  event['Records'].each do |record|
    logger.info("Processing SQS message: #{record.ai}")
    SlackEventsAPIHandler.new(record['body']).dispatch
  end

  {
    statusCode: 200,
    body: 'Message(s) processed.'
  }
end
