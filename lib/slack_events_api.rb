require 'logger'
require 'net/http'
require 'uri'
require 'aws-sdk-ssm'
require 'awesome_print'
require 'active_support'
require_relative 'openai_chat_bot'

class SlackEventsAPIHandler
  attr_reader :app_id, :user_id

  def initialize(slack_event)
    @logger = Logger.new(STDOUT)
    @slack_event = JSON.parse(slack_event)
    @logger.info("Slack event: #{@slack_event.ai}")
    
    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    environment = ENV['ENV'] || 'development'

    param_name = "slack_app_id-#{environment}"
    @app_id = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value

    param_name = "slack_user_id-#{environment}"
    @user_id = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value
    
    param_name = "slack_app_access_token-#{environment}"
    @access_token = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value
  end

  def event_type
    @slack_event['type']
  end

  def dispatch
    @logger.warn("Dispatching event of type: #{event_type}")

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
    @logger.debug("Handling event callback: #{@slack_event.ai}")

    case @slack_event['event']['type']
    when 'message'
      message
    when 'app_mention'
      app_mention
    else
      # Handle other event types if necessary
    end
  end

  def message_text
    @message_text ||=
      case @slack_event['event']['subtype']
      when 'message_deleted'
        @logger.info("Ignoring message_deleted event.")
        return
      when 'message_changed'
        @logger.info("Handling message_changed event.")
        @slack_event['event']['message']['text']
      else
        @slack_event['event']['text']
      end
  end

  def message
    @logger.info("Slack message event with text: \"#{message_text}\"")
  
    if (( event_mentions_me? or
          event_is_direct_message? ) and
            not event_is_from_me?)

      @logger.info("Responding to message event.")

      @response_slack_message = send_message(
        @slack_event['event']['channel'], '...')
      @logger.info("Response message: #{@response_slack_message.ai}")

      conversation_history = get_conversation_history(
        @slack_event['event']['channel'])
    
      gpt = GPT.new(
        slack_events_api_handler: self
      )
      chat_messages_list = gpt.build_chat_messages_list(conversation_history)

      update_message(
        @slack_event['event']['channel'], ':robot_face:',
          @response_slack_message['ts'])

      response = gpt.get_response(chat_messages_list)
    
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
    @logger.info("Sending message to Slack: #{text}")
    uri = URI.parse("https://slack.com/api/chat.postMessage")
  
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/x-www-form-urlencoded"
    request["Authorization"] = "Bearer #{@access_token}"
    request.set_form_data(
      "channel" => channel,
      "text" => text,
    )
  
    req_options = {
      use_ssl: uri.scheme == "https",
    }
  
    Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end.tap do |response|
      @logger.info("Sent message to Slack: #{response.body.ai}")
      return JSON.parse(response.body)
    end
  end

  def update_message(channel, text, ts)
    @logger.info("Updating existing message from timestamp #{ts} in Slack: #{text}")
    uri = URI.parse("https://slack.com/api/chat.update")
  
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/x-www-form-urlencoded"
    request["Authorization"] = "Bearer #{@access_token}"
    request.set_form_data(
      "channel" => channel,
      "text" => text,
      "ts" => ts, # Timestamp of the message to update
    )
  
    req_options = {
      use_ssl: uri.scheme == "https",
    }
  
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end.tap do |response|
      @logger.info("Updated message in Slack: #{response.body.ai}")
      return JSON.parse(response.body)
    end
  end

  def event_mentions_me?
    message_text_mentions_me = message_text.include?(@user_id)
    @logger.info("does \"#{message_text}\" mention the ID of this user, \"#{@user_id}\"?  #{message_text_mentions_me ? 'Yes!' : 'No.'}")
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
    event_is_from_me = event_app_id == @app_id
    @logger.info("is \"#{event_app_id}\" the ID of this app, \"#{@app_id}\"?  #{event_is_from_me ? 'Yes!' : 'No.'}")
    event_is_from_me
  end

  def event_is_direct_message?
    channel_type = @slack_event['event']['channel_type']
    event_is_direct_message = channel_type == 'im'
    @logger.info("is \"#{channel_type}\" the type of this channel, \"im\"?  #{event_is_direct_message ? 'Yes!' : 'No.'}")
    event_is_direct_message
  end

  def get_conversation_history(channel_id)
    uri = URI("https://slack.com/api/conversations.history?channel=#{channel_id}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    response_body = JSON.parse(response.body)
  
    if response_body['ok']
      messages = response_body['messages']
      @logger.info("Conversation history: #{messages.ai}")
      messages.reject{|message|
        message['ts'].eql? @response_slack_message['ts'] }.
        map do |message|
        {
          'user_id' => message['user'],
          'user_profile' => get_user_profile(message['user']),
          'message' => message['text']
        }
      end
    else
      @logger.error("Error getting conversation history: #{response_body['error']}")
      nil
    end
  end

  def get_user_profile(user_id)
    @profile_cache ||= {}
    if @profile_cache[user_id] && Time.now - @profile_cache[user_id][:timestamp] < 3600
      # Return the cached result if it's less than an hour old
      return @profile_cache[user_id][:data]
    end

    uri = URI("https://slack.com/api/users.profile.get?user=#{user_id}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    response_body = JSON.parse(response.body)
    
    if response_body['ok']
      profile = response_body['profile']
      @logger.info("User profile: #{profile}")
      
      # Cache the result with a timestamp
      @profile_cache[user_id] = { data: profile, timestamp: Time.now }
      
      profile
    else
      @logger.error("Error getting user profile: #{response_body['error']}")
      nil
    end
  end
  
end
