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
              "temperature"
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
    @@logger.info "Setting bot configuration setting: #{arguments.ai}"
    Configuration::Model.set(value: arguments['value'])

    {
      "message": "Set bot configuration setting: #{name} => #{arguments['value']}"
    }    
  end

end