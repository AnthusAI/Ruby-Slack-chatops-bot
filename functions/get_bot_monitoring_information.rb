require 'aws-sdk-cloudwatch'
require_relative '../lib/cloudwatch_metrics'
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
    cloudwatch_metrics = CloudWatchMetrics.new

    puts "Getting bot monitoring information..."
    {
      "metrics": [
        {
          'Average Slack Messages Received per minute in the last hour':
            cloudwatch_metrics.get_metric_average_over_time(
              metric_name: 'Slack Messages Received')
        },
        {
          'Average Slack Messages Sent per minute in the last hour':
          cloudwatch_metrics.get_metric_average_over_time(
              metric_name: 'Slack Messages Sent')
        },  
        {
          'Average Open AI Chat API Responses per minute in the last hour':
          cloudwatch_metrics.get_metric_average_over_time(
              metric_name: 'Open AI Chat API Responses')
        },
        {
          'Average Function Responses per minute in the last hour':
          cloudwatch_metrics.get_metric_average_over_time(
              metric_name: 'Function Responses')
        }
      ]
    }
  end

end