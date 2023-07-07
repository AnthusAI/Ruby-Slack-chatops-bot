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

        # Activity metrics.

        {
          'Number of Slack Messages Received in the last hour':
            cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'Slack Messages Received')
        },
        {
          'Number of Slack Messages Sent in the last hour':
          cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'Slack Messages Sent')
        },  
        {
          'Number of Open AI Chat API Responses in the last hour':
          cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'Open AI Chat API Responses')
        },
        {
          'Number of Function Responses in the last hour':
          cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'Function Responses')
        },

        # OpenAI token usage metrics.

        {
          'Number of OpenAI prompt tokens used in the last hour':
            cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Prompt Token Usage')
        },
        {
          'Number of OpenAI completion tokens used in the last hour':
            cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Completion Token Usage')
        },
        {
          'Number of OpenAI total tokens used in the last hour':
            cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Total Token Usage')
        },

        # OpenAI token cost metrics.
        
        {
          'OpenAI prompt token cost in the last hour in dollars':
            'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Input Token Cost').round(2).to_s
        },
        {
          'OpenAI completion tokens cost in the last hour in dollars':
          'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Output Token Cost').round(2).to_s
        },
        {
          'OpenAI total tokens cost in the last hour in dollars':
          'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Total Token Cost').round(2).to_s
        }
        
      ]
    }
  end

end