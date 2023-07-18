require_relative '../lib/helper.rb'

class GetBotSetting < Function

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

    $logger.info "Getting bot setting information: #{arguments.ai}"

    Configuration::Setting.find(key: arguments['key']).get

  end.tap do |result|
    $logger.debug "Result: #{result.ai}"
  end

end