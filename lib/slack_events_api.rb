require 'logger'
require 'net/http'
require 'uri'
require 'aws-sdk-ssm'

class SlackEventsAPI
  def initialize(event)
    @logger = Logger.new(STDOUT)
    @event = JSON.parse(event)
    @logger.info("Slack event: #{@event}")
    
    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    environment = ENV['ENV'] || 'development'

    param_name = "slack_app_id-#{environment}"
    @app_id = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value

    param_name = "slack_app_access_token-#{environment}"
    @access_token = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value
  end

  def dispatch
    case @event['type']
    when 'url_verification'
      url_confirmation
    when 'event_callback'
      handle_event_callback
    else
      # Handle unrecognized event types if necessary
    end
  end

  private

  def url_confirmation
    @event['challenge']
  end

  def handle_event_callback
    case @event['event']['type']
    when 'message'
      message
    else
      # Handle other event types if necessary
    end
  end

  def message
    message_text = @event['event']['text']
    @logger.info("Slack message event with text: \"#{message_text}\"")

    unless is_event_from_me?
      send_message(
        @event['event']['channel'],
        "You said: #{@event['event']['text']}")
    end
  end
  
  def send_message(channel, text)
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
  
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  end

  def is_event_from_me?
    @event['event']['app_id'] == @app_id
  end
  
end
