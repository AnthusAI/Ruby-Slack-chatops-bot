require 'logger'
require 'net/http'
require 'uri'
require 'aws-sdk-ssm'
require 'aws-sdk-secretsmanager'
require 'awesome_print'
require 'active_support'
require 'slack-ruby-client'
require_relative 'openai_chat_bot'
require_relative 'key_value_store'
require_relative 'slack_conversation_history'

class SlackEventsAPIHandler
  attr_reader :app_id, :user_id

  def initialize(slack_event)
    @logger = Logger.new(STDOUT)
    @logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO
    @slack_event = JSON.parse(slack_event)
    @logger.debug("Handling Slack event:\n#{slack_event.ai}")
    
    environment =         ENV['ENVIRONMENT'] || 'development'
    aws_resource_prefix = ENV['AWS_RESOURCE_PREFIX'] || 'slack-bot'
    @app_id =             ENV['SLACK_APP_ID']

    # Get the Slack app access token from AWS Secrets Manager.
    # (CloudFormation cannot create SSM SecureString parameters.)

    secretsmanager_client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    
    secret_name = "#{aws_resource_prefix}-slack-app-access-token-#{environment}"
    @slack_access_token = secretsmanager_client.get_secret_value(
      secret_id: secret_name
    ).secret_string
    @logger.debug "Slack app access token: #{@slack_access_token}"
  end

  def event_type
    @slack_event['type']
  end

  def dispatch
    @logger.debug("Dispatching event of type: #{event_type}")

    case event_type
    when 'url_verification'
      url_confirmation
    when 'event_callback'
      handle_event_callback
    else
      # Handle unrecognized event types if necessary
    end
  end

  def url_confirmation
    @slack_event['challenge']
  end

  def handle_event_callback
    case @slack_event['event']['type']
    when 'message'
      message unless message_subtype.eql? 'message_changed'
    when 'app_mention'
      app_mention
    else
      # Handle other event types if necessary
    end
  end

  def message_subtype
    return nil if @slack_event['event'].nil?
    @slack_event['event']['subtype']
  end

  def message_text
    @message_text ||=
      case message_subtype
      when 'message_changed'
        @logger.info("Handling message_changed event.")
        @slack_event['event']['message']['text']
      else
        @slack_event['event']['text']
      end
  end

  def message
    @logger.info("Slack message event on channel #{@slack_event['event']['channel']} with text: \"#{message_text}\"")

    case message_subtype
    when 'message_deleted'
      @logger.info("Ignoring message_deleted event.")
      return
    end
  
    if event_needs_processing?
      @logger.info("Responding to message event.")

      @response_slack_message = send_message(
        @slack_event['event']['channel'], ':gear:')
      @logger.info("Posted status response to Slack: #{@response_slack_message.ai}")

      conversation_history = get_conversation_history(
        @slack_event['event']['channel'])

      @logger.debug "Conversation history:\n#{conversation_history.ai}"

      gpt = GPT.new(
        slack_events_api_handler: self
      )
      chat_messages_list = gpt.build_chat_messages_list(conversation_history)

      update_message(
        @slack_event['event']['channel'], ':robot_face:',
          @response_slack_message['ts'])

      response = gpt.get_response(conversation_history:chat_messages_list)
    
      update_message(
        @slack_event['event']['channel'], response,
          @response_slack_message['ts'])
    else
      @logger.info("Not responding to message event.")
    end
    
  end

  def app_mention
    message_text = @slack_event['event']['text']
    @logger.info("Slack message event with text: \"#{message_text}\"")
  end
  
  def send_message(channel, text)
    @logger.debug("Sending message to Slack on channel #{channel}: \"#{text}\"")
    
    client = Slack::Web::Client.new(token: @slack_access_token)
    
    client.chat_postMessage(channel: channel, text: text).tap do |response|
      @logger.info("Sent message to Slack on channel #{channel}: #{response.inspect}")
    end
  end

  def update_message(channel, text, ts)
    @logger.info(
      "Updating existing message from timestamp #{ts} in Slack: #{text}")
  
    client = Slack::Web::Client.new(token: @slack_access_token)
  
    client.chat_update(
      channel: channel,
      text: text,
      ts: ts # Timestamp of the message to update
    ).tap do |response|
      @logger.info("Updated message in Slack: #{response.inspect}")
    end
  end

  def event_mentions_me?
    if user_id.blank?
      @logger.warn("This app does not have a user ID!")
      return false
    end
    message_text_mentions_me = message_text.include?(user_id || '')
    @logger.debug("does \"#{message_text}\" mention the ID of this user, \"#{@user_id}\"?  #{message_text_mentions_me ? 'Yes!' : 'No.'}")
    message_text_mentions_me
  end

  def event_app_id
    unless (id = @slack_event['event']['app_id']).blank?
      return id
    else
      unless (@slack_event['event']['message'].blank? ||
        id = @slack_event['event']['message']['app_id']).blank?
        return id
      end
    end
  end

  def event_is_from_me?
    event_is_from_me = (!event_app_id.blank?) and (event_app_id == @app_id)
    @logger.debug("is \"#{event_app_id}\" not blank and also the ID of this app, \"#{@app_id}\"?  #{event_is_from_me ? 'Yes!' : 'No.'}")
    event_is_from_me
  end

  def event_is_direct_message?
    channel_type = @slack_event['event']['channel_type']
    event_is_direct_message = channel_type == 'im'
    @logger.debug("is \"#{channel_type}\" the type of this channel, \"im\"?  #{event_is_direct_message ? 'Yes!' : 'No.'}")
    event_is_direct_message
  end

  def event_needs_processing?
    (( event_mentions_me? or
      event_is_direct_message? ) and
        not event_is_from_me?).tap do |does_event_need_processing|
          @logger.debug('Does this event need processing? ' +
            (does_event_need_processing ? 'Yes!' : 'No.'))
        end
  end

  def get_conversation_history(channel_id)
    (history = SlackConversationHistory.new(
      channel_id: @slack_event['event']['channel'])).
        fetch_from_slack

    messages = history.get_recent_messages(100)

    messages.map do |message|
      message.merge(
        'user_profile' => get_user_profile(message['user']))
    end
  end

  def get_user_profile(user_id)
    KeyValueStore.new.get(key:"user_profiles/#{user_id}") do
      Slack::Web::Client.new(token: @slack_access_token).
        users_profile_get(user: user_id)['profile']
    end
  end
  
  def bot_id
    @bot_id ||= KeyValueStore.new.get(key:'bot_id') do
      profile_info =
        Slack::Web::Client.new(token: @slack_access_token).users_profile_get
      profile_info['ok'] ? profile_info['profile']['bot_id'] : log_error_and_return_nil(profile_info['error'])
    end
  end
    
  def user_id
    @user_id ||= KeyValueStore.new.get(key:'user_id') do
      bot_info = 
        Slack::Web::Client.new(token: @slack_access_token).bots_info(bot: bot_id)
      bot_info['ok'] ?
        bot_info['bot']['user_id'] :
        log_error_and_return_nil(bot_info['error'])
    end
  end  
  
  def log_error_and_return_nil(error)
    @logger.error("Error: #{error}")
    nil
  end
  
end