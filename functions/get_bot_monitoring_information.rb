require 'aws-sdk-cloudwatch'
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
      "metrics": [
        {
          'Slack Messages Received':
            get_metric_average_over_time(ENV['SLACK_MESSAGES_RECEIVED_METRIC'])
        },
        {
          'Slack Messages Sent':
            get_metric_average_over_time(ENV['SLACK_MESSAGES_SENT_METRIC'])
        },  
        {
          'Open AI Chat API Responses':
            get_metric_average_over_time(ENV['OPEN_AI_CHAT_API_METRIC'])
        },
        {
          'Function Responses':
            get_metric_average_over_time(ENV['FUNCTION_RESPONSES_METRIC'])
        }
      ]
    }
  end

end