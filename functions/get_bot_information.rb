require 'aws-sdk-cloudwatch'
require_relative '../lib/cloudwatch_metrics'
require_relative '../lib/configuration_setting'

class GetBotInformation < Function

  def definition
    {
      name: name,
      description: "Get this bot's configuration setting values.  The 'key' parameter specifies a specific value to get.  The 'model' key returns the bot's current OpenAI model name setting.  The 'temperature' key returns the current OpenAI temperature setting.  The 'status_emojis' key returns whether status emojis are enabled or not.",
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
    cloudwatch_metrics = CloudWatchMetrics.new

    $logger.info "Getting bot monitoring information: #{arguments.ai}"

    case arguments['key']
    when 'status'
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
            'Number of Slack Messages Updated in the last hour':
            cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Updated')
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
    else
      Configuration::Setting.find(key: arguments['key']).get
    end
  end.tap do |result|
    $logger.debug "Result: #{result.ai}"
  end

end