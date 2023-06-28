require 'logger'
require 'aws-sdk-ssm'
require 'openai'

class GPT

  @@open_ai_models = {
    gpt3: {
      name: 'gpt-3.5-turbo-16k-0613',
      max_tokens: 16384,
      slack_messages_to_retrieve: 200
    },
    gpt4: {
      name: 'gpt-4-0613',
      max_tokens: 8192,
      slack_messages_to_retrieve: 100
    }
  }

  def initialize(slack_events_api_handler:)
    @logger = Logger.new(STDOUT)
    @slack_events_api_handler = slack_events_api_handler
    
    ssm_client = Aws::SSM::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
    environment = ENV['ENVIRONMENT'] || 'development'
  
    param_name = "open_ai_access_token-#{environment}"
    @open_ai_access_token = ssm_client.get_parameter(
      name: param_name, with_decryption: true
    ).parameter.value

    @open_ai_client = OpenAI::Client.new(access_token: @open_ai_access_token)
    @open_ai_model = ENV['OPEN_AI_MODEL']&.to_sym || :gpt3
    @logger.info "OpenAI model: #{model_name}"
  end
  
  # Convert the conversation history list of hashes that came from the Slack API
  # into a list of messages that can be passed to the OpenAI API.
  def build_chat_messages_list(conversation_history)
    # First, trim it to the maximum number of messages that we have set up
    # for the current model.  We use this as a rough estimate without doing
    # the slower work of counting tokens.
    conversation_history =
      (conversation_history || []).slice(0, slack_messages_to_retrieve)

    until (
      estimate_tokens(
        conversation_history.map{ |message| message['message'] }.join(' ')
      ) < model_max_tokens / 4 # 4k of history for a 16k model.
      # It's too expensive to send the entire conversation history to the
      # OpenAI API, so we trim it down until it's a reasonable size.
    )
      # If the conversation history is too long, remove the oldest message
      # and try again.
      @logger.info "Trimming conversation history."
      @logger.debug "First three items in conversation history: #{conversation_history[0..2].ai}"
      @logger.debug "Last three items in conversation history: #{conversation_history[-3..-1].ai}"
      conversation_history =
        conversation_history.slice(0, conversation_history.length - 1)
    end

    # This array represents the conversation history that will be passed to
    # the OpenAI API.
    [
      # Add a system prompt to the beginning of the conversation history.
      {
        role: "system",
        content: File.read(File.join(__dir__, '..', 'bot', 'system_prompt.txt'))
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
          @logger.info "Messages list: #{messages_list.ai}"
        end

  end

  def estimate_tokens(text, method = 'max')
    # method can be "average", "words", "chars", "max", "min", defaults to "max"
    # "average" is the average of words and chars
    # "words" is the word count divided by 0.75
    # "chars" is the char count divided by 4
    # "max" is the max of word and char
    # "min" is the min of word and char

    word_count = text.split(' ').count
    char_count = text.length
    tokens_count_word_est = word_count.to_f / 0.75
    tokens_count_char_est = char_count.to_f / 4.0

    # Include additional tokens for spaces and punctuation marks
    additional_tokens = text.scan(/[\s.,!?;]/).length

    tokens_count_word_est += additional_tokens
    tokens_count_char_est += additional_tokens

    output = 0
    if method == 'average'
      output = (tokens_count_word_est + tokens_count_char_est) / 2
    elsif method == 'words'
      output = tokens_count_word_est
    elsif method == 'chars'
      output = tokens_count_char_est
    elsif method == 'max'
      output = [tokens_count_word_est, tokens_count_char_est].max
    elsif method == 'min'
      output = [tokens_count_word_est, tokens_count_char_est].min
    else
      # return invalid method message
      return "Invalid method. Use 'average', 'words', 'chars', 'max', or 'min'."
    end

    output.to_i.tap do |output|
      @logger.info "Estimated tokens: #{output}"
    end
  end

  def get_response(conversation_history)

    # Send the conversation history to the OpenAI API.
    def api_response conversation_history
      @open_ai_client.chat(
        parameters: {
            # Get the model from the class instance.
            model: model_name,
            messages: conversation_history,
            temperature: 0.7,
        }).tap do |response|
          @logger.info "OpenAI Response: #{response.ai}"        
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
        # Abort if wehave tried too many times.
        loop_tries += 1
        break({ 'error' => { 'code' => 'too_many_tries' } }) if loop_tries > 10

        # Loop until the response is not a context-length error.
        response = api_response(conversation_history)
        break(response) unless response['error']
        @logger.info 'Error from OpenAI API.'

        case response['error']['code']

        # If the context length is exceeded, try again with a shorter context.
        when 'context_length_exceeded'
          @logger.info 'Context length exceeded. Retrying...'
          sleep 1
          conversation_history.shift  

        # For generale errors of "type" => "server_error" or anything else,
        # try again.
        else
          sleep 1
        end

      end
    
    response.dig("choices", 0, "message", "content").tap do |response|
      @logger.info "OpenAI Response: #{response}"
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