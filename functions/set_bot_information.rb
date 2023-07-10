class SetBotInformation < Function

  def definition
    {
      name: name,
      description: "Set this bot's configuration settings. The 'model' key sets the bot's current model name setting.",
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
        }
      }
    }
  end

  def execute(arguments)
    $logger.debug "Setting bot configuration setting: #{arguments.ai}"
    new_setting = Configuration::Setting.
      find(key: arguments['key']).set(value: arguments['value'])

    {
      arguments['key'] => new_setting,
      "message": "Set bot configuration setting: #{arguments['key']} => #{new_setting}"
    }    
  end

end