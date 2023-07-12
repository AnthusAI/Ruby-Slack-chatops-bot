require 'aws-sdk-cloudwatch'
require_relative '../lib/cloudwatch_metrics'
require_relative '../lib/configuration_setting'
require 'active_support/core_ext/integer/time'

class CheckBotHealth < Function

  def definition
    {
      name: name,
      description: "Get this bot's health status about the OpenAI model's integration with Slack by checking relevant CloudWatch metrics and alarms.  This function will also display a CloudWatch metric widget image in the Slack channel along with the text response from the OpenAI model.",
      parameters: {
        type: 'object',
        properties: {
          "time_range": {
            "type": "string",
            "enum": [
              "today",
              "this_week",
              "last_week",
              "last_month"
            ]
          }
        },
        "required": ["time_range"]
      }
    }
  end

  def execute(arguments)
    cloudwatch_metrics = CloudWatchMetrics.new

    $logger.info "Getting bot health monitoring information: #{arguments.ai}"

    minutes_ago =
      case arguments['time_range']
      when 'today'
        1440
      when 'this_week'
        10080
      when 'last_week'
        10080 * 2
      when 'last_month'
        10080 * 4
      else
        1440
      end
    seconds_ago = minutes_ago * 60

    time_window_string = ActiveSupport::Duration.build(seconds_ago).inspect

    environment = ENV['ENVIRONMENT'] || 'development'
    namespace = ENV['AWS_RESOURCE_NAME'].gsub(/ /,'')
    region = ENV['AWS_REGION'] || 'us-east-1'

    metric_widget_json = <<-JSON
      {
        "title": "Activity",
        "metrics": [
          [
            "#{namespace}",
            "Slack Messages Received",
            "Environment", "#{environment}",
            {
              "label": "Slack Messages Received"
            }
          ],
          [
            "#{namespace}",
            "Slack Reactions Sent",
            "Environment", "#{environment}",
            {
              "label": "Slack Reactions Sent"
            }
          ],
          [
            "#{namespace}",
            "Slack Messages Sent",
            "Environment", "#{environment}",
            {
              "label": "Slack Messages Sent"
            }
          ],
          [
            "#{namespace}",
            "Slack API Calls",
            "Environment", "#{environment}",
            {
              "label": "Slack API Calls"
            }
          ],
          [
            "#{namespace}",
            "Slack Messages Updated",
            "Environment", "#{environment}",
            {
              "label": "Slack Messages Updated"
            }
          ],
          [
            "#{namespace}",
            "Open AI Chat API Responses",
            "Environment", "#{environment}",
            {
              "label": "Open AI Chat API Responses"
            }
          ],
          [
            "#{namespace}",
            "Function Responses",
            "Environment", "#{environment}",
            {
              "label": "Function Responses"
            }
          ]
        ],
        "view": "timeSeries",
        "stacked": true,
        "region": "#{region}",
        "period": 60,
        "start": "-PT24H",
        "end": "P0D",
        "stat": "Sum",
        "yAxis": {
            "left": {
                "label": "count per minute",
                "showUnits": false
            },
            "right": {
                "showUnits": true
            }
        }
      }
    JSON

    $logger.info "Metric widget JSON:\n#{metric_widget_json}"

    metric_image_file_path =
      cloudwatch_metrics.get_cloudwatch_metric_widget_image(
        metric_widget_json: metric_widget_json)
    $logger.debug "Generated metric image at file path: #{metric_image_file_path}"

    @response_channel.upload_file(file_path: metric_image_file_path)

    {
      "summary":
        [
          "Bot health monitoring information for the last #{time_window_string}: ",
          "Number of Slack messages sent: #{cloudwatch_metrics.get_metric_sum_over_time(
            metric_name: 'Slack Messages Sent',
            time_window: seconds_ago)}",
          "Estimated total cost of OpenAI tokens used: USD $#{cloudwatch_metrics.get_metric_sum_over_time(
            metric_name: 'OpenAI Total Token Cost',
            time_window: seconds_ago).round(2)}"
        ].join(' '),

      "attachments": "Tell the user that you're attaching a CloudWatch metric widget image.",

      "details": {

        "metrics": [

          # Activity metrics.

          {
            "Number of Slack Messages Received in the last #{time_window_string}":
              cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Received',
                time_window: seconds_ago)
          },
          {
            "Number of Slack Messages Sent in the last #{time_window_string}":
            cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Sent',
                time_window: seconds_ago)
          },  
          {
            "Number of Slack Messages Updated in the last #{time_window_string}":
            cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Updated',
                time_window: seconds_ago)
          },  
          {
            "Number of Open AI Chat API Responses in the last #{time_window_string}":
            cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Open AI Chat API Responses',
                time_window: seconds_ago)
          },
          {
            "Number of Function Responses in the last #{time_window_string}":
            cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Function Responses',
                time_window: seconds_ago)
          },

          # OpenAI token usage metrics.

          {
            "Number of OpenAI prompt tokens used in the last #{time_window_string}":
              cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Prompt Token Usage',
                time_window: seconds_ago,
                time_window: seconds_ago)
          },
          {
            "Number of OpenAI completion tokens used in the last #{time_window_string}":
              cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Completion Token Usage',
                time_window: seconds_ago,
                time_window: seconds_ago)
          },
          {
            "Number of OpenAI total tokens used in the last #{time_window_string}":
              cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Total Token Usage',
                time_window: seconds_ago,
                time_window: seconds_ago)
          },

          # OpenAI token cost metrics.
          
          {
            "OpenAI prompt token cost in the last #{time_window_string} in dollars":
              'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Input Token Cost',
                time_window: seconds_ago).round(2).to_s
          },
          {
            "OpenAI completion tokens cost in the last #{time_window_string} in dollars":
            'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Output Token Cost',
                time_window: seconds_ago).round(2).to_s
          },
          {
            "OpenAI total tokens cost in the last #{time_window_string} in dollars":
            'USD $' + cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Total Token Cost',
                time_window: seconds_ago).round(2).to_s
          }
          
        ]
      }
    }
  end.tap do |result|
    $logger.debug "Result: #{result.ai}"
  end

end