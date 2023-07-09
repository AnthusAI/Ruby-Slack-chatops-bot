require 'json'
require_relative 'lib/helper'
require_relative 'lib/slack_events_api'

def sqs_message_processor_lambda_handler(event:, context:)
  logger = Logger.new(STDOUT)
  logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO
  logger.debug("Received event from Lambda:\n#{JSON.pretty_generate(event)}")

  event['Records'].each do |record|
    logger.debug("Processing SQS message: #{record.ai}")
    SlackEventsAPIHandler.new(record['body']).dispatch
  end

  {
    statusCode: 200,
    body: 'Message(s) processed.'
  }
end
