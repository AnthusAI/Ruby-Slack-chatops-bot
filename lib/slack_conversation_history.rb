require 'aws-sdk-ssm'
require 'aws-sdk-dynamodb'
require_relative 'openai_token_estimator'

class SlackConversationHistory
  def initialize(channel_id:)
    @channel_id = channel_id
    @logger = Logger.new(STDOUT)
    @logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO
    @dynamodb = Aws::DynamoDB::Client.new
    @table_name = ENV['SLACK_CONVERSATION_HISTORY_TABLE']

    environment =         ENV['ENVIRONMENT'] || 'development'
    aws_resource_prefix = ENV['AWS_RESOURCE_PREFIX'] || 'slack-bot'

    # Get the Slack app access token from AWS Secrets Manager.
    # (CloudFormation cannot create SSM SecureString parameters.)

    secretsmanager_client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    
    secret_name = "#{aws_resource_prefix}-slack-app-access-token-#{environment}"
    @slack_access_token = secretsmanager_client.get_secret_value(
      secret_id: secret_name
    ).secret_string
    @logger.debug "Slack app access token: #{@slack_access_token}"
  end

  def fetch_from_slack
    client = Slack::Web::Client.new(token: @slack_access_token)
    response = client.conversations_history(channel: @channel_id, limit: 200)

    if response['ok']
      messages = response['messages']
      @logger.debug("Fetched conversation history for channel #{@channel_id}:\n#{JSON.pretty_generate(messages.inspect)}")

      messages.reject { |message| 
        @response_slack_message &&
        message['ts'].eql?(@response_slack_message['ts'])
      }.map do |message|
        store_message_in_dynamo(
          user_id: message['user'], 
          message: message['text'], 
          ts: message['ts']
        )
      end
    else
      @logger.error("Error getting conversation history: #{response['error']}")
      nil
    end
  end

  def get_message(ts)
    params = {
      table_name: @table_name,
      key: {
        'channelId' => @channel_id,
        'ts' => ts.to_f
      }
    }
    
    response = @dynamodb.get_item(params)
    response.item
  end

  def get_recent_messages(n)
    params = {
      table_name: @table_name,
      key_condition_expression: "channelId = :channelId",
      expression_attribute_values: {
        ":channelId" => @channel_id
      },
      limit: n,
      scan_index_forward: false  # Get results in reverse order of the sort key
    }
  
    response = @dynamodb.query(params)
    response.items
  end

  private

  def store_message_in_dynamo(user_id:, message:, ts:)
    # First, check if the item already exists
    existing_item = get_message(ts)
    
    # If the item doesn't exist, compute the tokens and store the new item
    if (
      existing_item.nil? or
      # If we have a cached value then we can't necessarily use it, because
      # messages in the history can be updated. So we need to check if the
      # message has changed, and if so, update the cached value.
      !existing_item['message'].eql?(message)
    )

      token_estimate = OpenAITokenEstimator.estimate_token_count(message)
  
      params = {
        table_name: @table_name,
        item: {
          'channelId' => @channel_id,
          'ts' => ts.to_f,
          'userId' => user_id,
          'message' => message,
          'estimatedOpenAiTokenCount' => token_estimate
        }
      }
  
      @dynamodb.put_item(params).to_h
    else
      return existing_item
    end
  end
  

end
