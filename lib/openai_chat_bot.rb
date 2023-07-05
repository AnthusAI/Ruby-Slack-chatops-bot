require 'logger'
require 'aws-sdk-ssm'
require 'aws-sdk-secretsmanager'
require 'active_support'
require 'openai'
require_relative 'openai_token_estimator'
require_relative 'function'
class GPT

  @@open_ai_models = {
    gpt3: {
      name: 'gpt-3.5-turbo-16k-0613',
      max_tokens: 16384
    },
    gpt4: {
      name: 'gpt-4-0613',
      max_tokens: 8192
    }
  }

  def initialize(slack_events_api_handler:)
    @logger = Logger.new(STDOUT)
    @logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO
    @slack_events_api_handler = slack_events_api_handler

    @function = Function.load

    environment =         ENV['ENVIRONMENT'] || 'development'
    aws_resource_prefix = ENV['AWS_RESOURCE_PREFIX'] || 'slack-bot'

    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')

    param_name = "#{aws_resource_prefix}-system-prompt-#{environment}"
    begin
      @system_prompt = ssm_client.get_parameter(
        name: param_name
      ).parameter.value
      @logger.debug "System prompt from SSM: \"#{@system_prompt}\""
    
      # If the parameter is not found, set the SSM value from the file and use it as system prompt
      if @system_prompt.blank?
        @logger.info "System prompt in SSM is blank. Setting default."
        default_prompt = File.read(
          File.join(__dir__, '..', 'default_openai_system_prompt.txt'))
        ssm_client.put_parameter({
          name: param_name,
          value: default_prompt,
          type: "String",
          overwrite: true
        })
        @system_prompt = default_prompt
      end
      
      @logger.debug "System prompt:\n\n#{@system_prompt.gsub(/^/m,'  ')}"
    end

    # Get the OpenAI API access token from AWS Secrets Manager.
    # (CloudFormation cannot create SSM SecureString parameters.)

    secretsmanager_client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    
    secret_name = "#{aws_resource_prefix}-openai-api-token-#{environment}"
    @open_ai_access_token = secretsmanager_client.get_secret_value(
      secret_id: secret_name
    ).secret_string
    @logger.debug "OpenAI access token: #{@open_ai_access_token}"

    @open_ai_client = OpenAI::Client.new(access_token: @open_ai_access_token)
    @open_ai_model = ENV['OPEN_AI_MODEL']&.to_sym || :gpt4
    @logger.debug "OpenAI model: #{model_name}"
  end
  
  # Convert the conversation history list of hashes that came from the Slack API
  # into a list of messages that can be passed to the OpenAI API.
  def build_chat_messages_list(conversation_history)

    # First, trim it to the maximum number of messages that we have set up
    # for the current model.  We use this as a rough estimate without doing
    # the slower work of counting tokens.
    # conversation_history =
    #   (conversation_history || []).slice(0, slack_messages_to_retrieve)

    # It's too expensive to send the entire conversation history to the
    # OpenAI API, so we trim it down until it's a reasonable size.
    until (
      (conversation_history.sum{|message|
        message['estimatedOpenAiTokenCount'].to_i }) <
          (model_max_tokens / 8)
    ) do
      # If the conversation history is too long, remove the oldest message
      # and try again.
      @logger.info "Trimming conversation history."
      conversation_history =
        conversation_history.slice(0, conversation_history.length - 1)
    end

    # This array represents the conversation history that will be passed to
    # the OpenAI API.
    [
      # Add a system prompt to the beginning of the conversation history.
      {
        role: "system",
        content: @system_prompt
      }
    ] +
      conversation_history.
        # Reverse the conversation history so that the oldest messages
        # are first.
        reverse.
        # Transform each Slack message into a hash with the role and content
        # keys that the OpenAI API expects.
        map do |message|
          if message['user_id'] == @slack_events_api_handler.user_id
            { role: "assistant", content: message['message'] }
          else
            { role: "user", content: message['message'] }
          end
        end.tap do |messages_list|
          @logger.debug "Messages list: #{messages_list.ai}"
        end

  end

  def get_response(
    conversation_history:, function_call:nil)

    @logger.info "Getting response to conversation history ending with (last 3):\n#{conversation_history.last(3).ai}"

    # Call the function if it's a function call.
    function_name = nil
    function_response =
      if function_call.present?
        @logger.info "Getting response to function call: #{function_call.ai}"
        function_name = function_call['name']
        function = @function.instances.
          select{|f| f.name == function_name}.first
        @logger.info "Calling function: #{function.ai}"
        function.execute(function_call['parameters']).tap do |response|
          @logger.info "Function response: #{response.ai}"
        end
      end

    # Send the conversation history to the OpenAI API.
    def api_response(conversation_history:,
      function_response:nil, function_name:nil)
      if function_response.present?
        conversation_history << {
          'role': 'function',
          'name': function_name,
          'content': function_response.to_json,
        }
        @logger.info "Conversation history (last 3) with function response:\n#{conversation_history.last(3).ai}"
      end

      @open_ai_client.chat(
        parameters: {
            # Get the model from the class instance.
            model: model_name,
            messages: conversation_history,
            functions: @function.definitions,
            function_call: "auto",
            temperature: 0.7,
        }).tap do |response|
          @logger.info "OpenAI chat API response: #{response.ai}"        
        end
    end

    # This section will automatically trim down the conversation history
    # until the response empirically fits within the context window of the
    # current OpenAI model.
    #
    # We have already attempted to cut the conversation history down to an
    # appropriate size in the build_chat_messages_list method by estimating
    # the number of tokens in the conversation history and removing the oldest
    # messages first.  But, that's just an estimate.  The OpenAI API will
    # return an error if the context window is exceeded in real life, and then
    # if that happens we handle it.  We want to avoid that because it slows
    # down the response time.

    loop_tries = 0

    response = 
      loop do
        # Abort if we have tried too many times.
        loop_tries += 1
        break({ 'error' => { 'code' => 'too_many_tries' } }) if loop_tries > 3

        # Loop until the response is not a context-length error.
        response = api_response(
          conversation_history: conversation_history,
          function_response:    function_response,
          function_name:        function_name
        )
        break(response) unless response['error']
        @logger.error "Error from OpenAI API. Retrying...\n#{response.ai}"

        case response['error']['code']

        # If the context length is exceeded, try again with a shorter context.
        when 'context_length_exceeded'
          @logger.warn 'Context length exceeded. Retrying...'
          sleep 1
          conversation_history.shift  

        # For general errors of "type" => "server_error" or anything else,
        # try again.
        else
          sleep 1
        end

      end

      # If it's a function call then we need to handle that differently.
      response_message = response.dig("choices", 0, "message")
      @logger.info "OpenAI response message:\n#{response_message.ai}"

      if response_message['function_call'].present?
        @logger.info "Recursing to get a response to the function call: #{response_message['function_call']}"

        # Recurse to get the response to the function call.
        get_response(
          conversation_history: conversation_history,
          function_call: response_message['function_call']
        )
      else
        response_message['content'].tap do |response|
          @logger.info "OpenAI response message content: #{response}"
      end
    end
  end

  def model_name
    @@open_ai_models[@open_ai_model][:name]
  end

  def model_max_tokens
    @@open_ai_models[@open_ai_model][:max_tokens]
  end

  def slack_messages_to_retrieve
    @@open_ai_models[@open_ai_model][:slack_messages_to_retrieve]
  end

end