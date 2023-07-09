require_relative 'helper'

class OpenAITokenEstimator

  def self.estimate_token_count(text, method = 'max')
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
      $logger.info "Estimated tokens: #{output}"
    end

  end

end