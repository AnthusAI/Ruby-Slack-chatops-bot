require 'json'
require 'aws-sdk-secretsmanager'
require 'openai'
require 'open-uri'
require_relative 'lib/helper'
require_relative 'lib/slack_channel'

def handle_alarm_notifications_lambda_handler(event:, context:)
  $logger.info("Handling alarm notifications:\n#{JSON.pretty_generate(event)}")

  environment =         ENV['ENVIRONMENT'] || 'development'
  aws_resource_prefix = ENV['AWS_RESOURCE_PREFIX'] || 'slack-bot'
  secretsmanager_client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')

  secret_name = "#{aws_resource_prefix}-slack-app-access-token-#{environment}"
  @slack_access_token = secretsmanager_client.get_secret_value(
    secret_id: secret_name
  ).secret_string
  $logger.debug "Slack app access token: #{@slack_access_token}"
  
  secret_name = "#{aws_resource_prefix}-openai-api-token-#{environment}"
  @open_ai_access_token = secretsmanager_client.get_secret_value(
    secret_id: secret_name
  ).secret_string
  $logger.debug "OpenAI access token: #{@open_ai_access_token}"
  
  @open_ai_client = OpenAI::Client.new(access_token: @open_ai_access_token)
  
  @slack_channel = SlackChannel.new(
    slack_access_token: @slack_access_token,
    channel: 'ticket-driver-copilot-lab')

  event['Records'].each do |record|
    parsed_record = JSON.parse(record['Sns']['Message'])
    $logger.info("Processing alarm notification: #{JSON.pretty_generate(parsed_record)}")

    # Set the prompt for Dall-E based on the alarm state
    if parsed_record['NewStateValue'] == 'ALARM'
      prompt = "Three red blinking, rectangular, unlabeled status lights on a spaceship dashboard are lit up in red."
      filename = 'ALARM.png'
    else
      prompt = "Three green blinking, rectangular, unlabeled status lights on a spaceship dashboard are lit up in green."
      filename = 'OK.png'
    end
    
    # Request the image from the Dall-E API
    image_data =
      @open_ai_client.images.generate(parameters: { prompt: prompt })
    remote_image_url = image_data.dig("data", 0, "url")
    $logger.info "Dall-E image URL: #{remote_image_url}"

    # Download the image data to a local file.
    image_data = URI.open(remote_image_url).read

    # # Create a temporary file and write the image data to it
    image_file = Tempfile.new([filename, '.png'])
    image_file.write(image_data)
    image_file.rewind

    $logger.info "Downloaded temporary image file: #{image_file.path}"

    @slack_channel.send_message(
      text: "Alarm #{parsed_record['AlarmName']} changed state to #{parsed_record['NewStateValue']} at #{parsed_record['StateChangeTime']}.")

    # Send the image to the Slack channel
    @slack_channel.upload_file(file_path: image_file.path, file_name: filename)
    
    # Ensure the tempfile is closed and removed
    image_file.close
    image_file.unlink
  end

  {
    statusCode: 200,
    body: 'Message(s) processed.'
  }
end
