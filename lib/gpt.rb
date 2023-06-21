require 'logger'
require 'aws-sdk-ssm'
require 'openai'

class GPT

  def initialize(slack_events_api_handler:)
    @logger = Logger.new(STDOUT)
    @slack_events_api_handler = slack_events_api_handler
    
    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    environment = ENV['ENV'] || 'development'
  
    param_name = "open_ai_access_token-#{environment}"
    @open_ai_access_token = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value

    @open_ai = OpenAI::Client.new(access_token: @open_ai_access_token)
  end
  
  def get_response(conversation_history)
    response = client.chat(
        parameters: {
            model: "gpt-3.5-turbo", # Required.
            messages: [{ role: "user", content: "Hello!"}], # Required.
            temperature: 0.7,
        })
    @logger.info "OpenAI Response: #{response.dig("choices", 0, "message", "content")}"
  end

  # Convert the conversation history hash that came from the Slack API
  # into a list of messages that can be passed to the OpenAI API.
  def build_chat_messages_list(conversation_history)
    conversation_history.reverse.map do |message|
      if message['user_id'] == @slack_events_api_handler.bot_id
        { role: "assistant", content: message['message'] }
      else
        { role: "user", content: message['message'] }
      end
    end
  end

end