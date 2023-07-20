require 'babulus'

class GetBotSetting < Babulus::Function

  def definition
    {
      name: name,
      description: "Get this bot's configuration setting values.  This is for configuration settings, not for metrics or statistics or data.  The 'key' parameter specifies a specific value to get.  The 'model' key returns the bot's current OpenAI model name setting.  The 'temperature' key returns the current OpenAI temperature setting.  The 'status_emojis' key returns whether status emojis are enabled or not.",
      parameters: {
        type: 'object',
        properties: {
          "key": {
            "type": "string",
            "enum": [
              "model",
              "temperature",
              "status_emojis"
            ]
          }
        },
        "required": ["key"]
      }
    }
  end

  def execute(arguments)

    $logger.info "Getting bot setting information:\n#{JSON.pretty_generate(arguments)}"

    Babulus::Configuration::Setting.find(key: arguments['key']).get

  end.tap do |result|
    $logger.debug "Result: #{JSON.pretty_generate(result)}"
  end

end
