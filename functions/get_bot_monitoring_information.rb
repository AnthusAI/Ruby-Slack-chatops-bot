class GetBotMonitoringInformation < Function

  def name
    'get_bot_monitoring_information'
  end

  def definition
    {
      'name': name,
      'description': "Monitor this bot's status by checking relevant storage values, metrics and alarms for the OpenAI model's integration with Slack.",
      'parameters': {
        'type': 'object',
        'properties': {}
      }
    }
  end

  def execute(parameters)
    puts "Getting bot monitoring information..."
    {
      "status": 'OKAY',
      'summary': 'All systems are nominal.',
      "alarms": [
        { 'critical-something-alarm': 'OKAY' },
        { 'some-other-alarm-1': 'OKAY' },
        { 'some-other-alarm-2': 'OKAY' }
      ]
    }
  end

end