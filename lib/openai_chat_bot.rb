require 'json'
require 'bigdecimal'
require 'aws-sdk-ssm'
require 'aws-sdk-secretsmanager'
require 'active_support'
require 'openai'
require_relative 'helper'
require_relative 'openai_token_estimator'
require_relative 'function'
require_relative 'cloudwatch_metrics'
require_relative 'configuration_setting'

class GPT

  @@open_ai_models = {
    'gpt-3.5-turbo-0613' => {
      max_tokens: 4096,
      input_token_cost:  BigDecimal('0.0015') / BigDecimal('1000'),
      output_token_cost: BigDecimal('0.002') / BigDecimal('1000')
    },
    'gpt-3.5-turbo-16k-0613' => {
      name: 'gpt-3.5-turbo-16k-0613',
      max_tokens: 16384,
      input_token_cost:  BigDecimal('0.003') / BigDecimal('1000'),
      output_token_cost: BigDecimal('0.004') / BigDecimal('1000')
    },
    'gpt-4-0613' => {
      max_tokens: 8192,
      input_token_cost:  BigDecimal('0.03') / BigDecimal('1000'),
      output_token_cost: BigDecimal('0.06') / BigDecimal('1000')
    }
  }

  def initialize(slack_events_api_handler:, response_channel:)
    @cloudwatch_metrics = CloudWatchMetrics.new

    @slack_events_api_handler = slack_events_api_handler
    @response_channel = response_channel

    @function = Function.load

    environment =         ENV['ENVIRONMENT'] || 'development'
    aws_resource_prefix = ENV['AWS_RESOURCE_PREFIX'] || 'slack-bot'

    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')

    param_name = "#{aws_resource_prefix}-system-prompt-#{environment}"
    begin
      @system_prompt = ssm_client.get_parameter(
        name: param_name
      ).parameter.value
      $logger.debug "System prompt from SSM: \"#{@system_prompt}\""
    
      # If the parameter is not found, set the SSM value from the file and use it as system prompt
      if @system_prompt.blank?
        $logger.info "System prompt in SSM is blank. Setting default."
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
      
      $logger.debug "System prompt:\n\n#{@system_prompt.gsub(/^/m,'  ')}"
    end

    # Get the OpenAI API access token from AWS Secrets Manager.
    # (CloudFormation cannot create SSM SecureString parameters.)

    secretsmanager_client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    
    secret_name = "#{aws_resource_prefix}-openai-api-token-#{environment}"
    @open_ai_access_token = secretsmanager_client.get_secret_value(
      secret_id: secret_name
    ).secret_string
    $logger.debug "OpenAI access token: #{@open_ai_access_token}"

    @open_ai_client = OpenAI::Client.new(access_token: @open_ai_access_token)

    $logger.debug "OpenAI model: #{open_ai_model_name}"
  end

  def open_ai_model_name
    ENV['OPEN_AI_MODEL'] ||
      Configuration::Model.new.get
  end

  def temperature
    ENV['TEMPERATURE'] ||
      Configuration::Temperature.new.get
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
          (model_max_tokens / 2) # Half the max tokens
    ) do
      # If the conversation history is too long, remove the oldest message
      # and try again.
      $logger.info "Trimming conversation history."
      conversation_history =
        conversation_history.slice(0, conversation_history.length - 1)
    end

    # This array represents the conversation history that will be passed to
    # the OpenAI API.
    messages_list =
    (
      [
        # Add a system prompt to the beginning of the conversation history.
        {
          # GPT 3.5 is not good at paying attention to the system prompt,
          # and OpenAI recommends that we use the user prompt instead.
          role: (open_ai_model_name =~ /gpt3/) ? 'user' : 'system',
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
            $logger.debug "Message from Slack: #{message.ai}"

            # Format the timestamp into a human-readable (and LLM-readable)
            # string, like "FRI JUL 7 4:20 PM"
            timestamp = message['ts']
            time = Time.at(timestamp)
            formatted_time = time.strftime("%a %b %e %l:%M %p").upcase
            $logger.debug "Formatted time: #{formatted_time}"

            real_name = message['user_profile']['real_name']

            if message['userId'] == @slack_events_api_handler.user_id
              {
                role: "assistant",
                content: "#{message['message']}"
              }
            else
              {
                role: "user",
                # Example:
                # FRI JUL 7 4:20 PM - Ryan: Hi, Bot.
                content: "#{formatted_time} - #{real_name}: #{message['message']}"
              }
            end
          end
    )
    
    # Remove the last entry if it's an assistant response.
    if messages_list.last[:role] == 'assistant'
      messages_list.pop
    end

    messages_list.tap do |messages_list|
      $logger.info "Messages list: #{messages_list.ai}"
    end

  end

  def get_response(
    conversation_history:, function_call:nil)

    $logger.info "Getting response to conversation history ending with (last 10):\n#{conversation_history.last(10).ai}"

    # Call the function if it's a function call.
    function_name = nil
    function_response =
      if function_call.present?
        $logger.info "Getting response to function call: #{function_call.ai}"
        @response_channel.update_message(
          text: ':wrench:')

        function_name = function_call['name']
        function = @function.instances.
          select{|f| f.name == function_name}.first
        $logger.info "Calling function: #{function.ai}"
        function.execute(JSON.parse(function_call['arguments'])).tap do |response|
          $logger.info "Function response: #{response.ai}"
          @cloudwatch_metrics.send_metric_reading(
            metric_name: "Function Responses",
            value: 1,
            unit: 'Count'
          )
        end
      else
        $logger.info "No function call required."
        @cloudwatch_metrics.send_metric_reading(
          metric_name: "Function Calls Not Required",
          value: 1,
          unit: 'Count'
        )
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
        $logger.info "Conversation history (last 3) with function response:\n#{conversation_history.last(3).ai}"
      end

      @open_ai_client.chat(
        parameters: {
            # Get the model from the class instance.
            model: open_ai_model_name,
            messages: conversation_history,
            functions: @function.definitions,
            function_call: "auto",
            temperature: 0.7,
        }).tap do |response|
          $logger.info "OpenAI chat API response: #{response.ai}"
          # Record the activity on a per-model basis.
          @cloudwatch_metrics.send_metric_reading(
            metric_name: "Open AI Chat API Responses",
            dimensions: [
              name: 'Model',
              value: open_ai_model_name
            ],
            value: 1,
            unit: 'Count'
          )
          # CloudWatch isn't great at aggregating metrics across dimensions,
          # so we also record the activity across all models.
          # (The same data as above, but without a "Model" dimension.)
          @cloudwatch_metrics.send_metric_reading(
            metric_name: "Open AI Chat API Responses",
            value: 1,
            unit: 'Count'
          )

          if response['usage'].present?
            @cloudwatch_metrics.send_metric_reading(
              metric_name: "OpenAI Prompt Token Usage",
              value: response['usage']['prompt_tokens'],
              unit: 'Count'
            )
            @cloudwatch_metrics.send_metric_reading(
              metric_name: "OpenAI Completion Token Usage",
              value: response['usage']['completion_tokens'],
              unit: 'Count'
            )
            @cloudwatch_metrics.send_metric_reading(
              metric_name: "OpenAI Total Token Usage",
              value: response['usage']['total_tokens'],
              unit: 'Count'
            )

            # Compute the cost of those tokens.
            log_openai_call_cost(
              input_tokens_used:  response['usage']['prompt_tokens'],
              output_tokens_used: response['usage']['completion_tokens'],
              openai_model: open_ai_model_name
            )

          end
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
        $logger.error "Error from OpenAI API. Retrying...\n#{response.ai}"

        case response['error']['code']

        # If the context length is exceeded, try again with a shorter context.
        when 'context_length_exceeded'
          $logger.warn 'Context length exceeded. Retrying...'
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
      $logger.info "OpenAI response message:\n#{response_message.ai}"

      if response_message['function_call'].present?
        $logger.info "Recursing to get a response to the function call: #{response_message['function_call']}"

        # Recurse to get the response to the function call.
        get_response(
          conversation_history: conversation_history,
          function_call: response_message['function_call']
        )
      else
        response_message['content'].tap do |response|
          $logger.info "OpenAI response message content: #{response}"
      end
    end
  end

  def model_max_tokens
    @@open_ai_models[open_ai_model_name][:max_tokens]
  end

  def slack_messages_to_retrieve
    @@open_ai_models[open_ai_model_name][:slack_messages_to_retrieve]
  end

  # Compute the cost of an OpenAI call in dollars, based on the number of
  # input and output tokens used.
  def log_openai_call_cost(
    input_tokens_used:, output_tokens_used:, openai_model:)
    
    @cloudwatch_metrics.send_metric_reading(
      metric_name: "OpenAI Input Token Cost",
      value: input_token_cost =
        BigDecimal(input_tokens_used) *
          @@open_ai_models[open_ai_model_name][:input_token_cost],
      unit: 'Count'
    )
    
    @cloudwatch_metrics.send_metric_reading(
      metric_name: "OpenAI Output Token Cost",
      value: output_token_cost =
        BigDecimal(input_tokens_used) *
          @@open_ai_models[open_ai_model_name][:output_token_cost],
      unit: 'Count'
    )

    @cloudwatch_metrics.send_metric_reading(
      metric_name: "OpenAI Total Token Cost",
      value: input_token_cost + output_token_cost,
      unit: 'Count'
    )
  end
  
end