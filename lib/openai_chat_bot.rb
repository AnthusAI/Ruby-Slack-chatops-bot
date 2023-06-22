require 'logger'
require 'aws-sdk-ssm'
require 'openai'

class GPT

  def initialize(slack_events_api_handler:, max_conversation_history_length:10)
    @logger = Logger.new(STDOUT)
    @slack_events_api_handler = slack_events_api_handler
    @max_conversation_history_length = max_conversation_history_length
    
    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    environment = ENV['ENV'] || 'development'
  
    param_name = "open_ai_access_token-#{environment}"
    @open_ai_access_token = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value

    @open_ai_client = OpenAI::Client.new(access_token: @open_ai_access_token)
  end
  
  # Convert the conversation history hash that came from the Slack API
  # into a list of messages that can be passed to the OpenAI API.
  def build_chat_messages_list(conversation_history)
    [{ role: "system", content: File.read('system_prompt.txt') }] +
    conversation_history.
      slice(0,@max_conversation_history_length).
      reverse.
      map do |message|
        if message['user_id'] == @slack_events_api_handler.user_id
          { role: "assistant", content: message['message'] }
        else
          { role: "user", content: message['message'] }
        end
      end.tap do |messages_list|
        @logger.info "Messages list: #{messages_list.ai}"
      end
  end

  def get_response(conversation_history)
    response = @open_ai_client.chat(
      parameters: {
          model: "gpt-3.5-turbo",
          messages: conversation_history,
          temperature: 0.7,
      }).tap do |response|
        @logger.info "OpenAI Response: #{response.ai}"
      end
    response.dig("choices", 0, "message", "content").tap do |response|
      @logger.info "OpenAI Response: #{response}"
    end
  end

end