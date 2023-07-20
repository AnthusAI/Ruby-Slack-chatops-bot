require 'babulus'

class SetBotSetting < Babulus::Function

  def definition
    {
      name: name,
      description: "Get this bot's configuration setting values.  The 'key' parameter specifies a specific value to set.  The 'model' key sets the bot's current OpenAI model name setting.  The 'temperature' key sets the current OpenAI temperature setting.  The 'status_emojis' key sets whether status emojis are enabled or not.",
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
          },
          "value": {
            "type": "string"
          }
        },
        "required": ["key"]
      }
    }
  end

  def execute(arguments)
    $logger.debug "Setting bot configuration setting:\n#{JSON.pretty_generate(arguments)}"
    new_setting = Configuration::Setting.
      find(key: arguments['key']).set(value: arguments['value'])

    {
      arguments['key'] => new_setting,
      "message": "Set bot configuration setting: #{arguments['key']} => #{new_setting}"
    }    
  end

end