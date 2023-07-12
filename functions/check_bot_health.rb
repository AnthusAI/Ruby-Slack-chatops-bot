require 'time'
require 'aws-sdk-cloudwatch'
require_relative '../lib/cloudwatch_metrics'
require_relative '../lib/configuration_setting'
require 'active_support/core_ext/integer/time'

class CheckBotHealth < Function

  @@cloudwatch_metrics = CloudWatchMetrics.new

  def definition
    description = <<~DESCRIPTION
      Get this bot's health status about the OpenAI model's integration with Slack by checking relevant CloudWatch metrics and alarms.  This function will also display a CloudWatch metric widget image in the Slack channel along with the text response from the OpenAI model.
      A time range is required.
    
      Example usage:
    
        User: "How are you?"
        Function call: check_bot_health(key: "summary", time_range: "today")
    
        User: "How have you been recently?"
        Function call: check_bot_health(key: "summary", time_range: "last_day")
    
        User: "How are you now?"
        Function call: check_bot_health(key: "summary", time_range: "last_hour")

        User: "How are your metrics?"
        Function call: check_bot_health(key: "metrics", time_range: "last_hour")

        User: "Show me weekly stats."
        Function call: check_bot_health(key: "metrics", time_range: "last_week")

        User: "What's your data from the last month?"
        Function call: check_bot_health(key: "metrics", time_range: "last_month")
    DESCRIPTION

    {
      name: name,
      description: description,
      parameters: {
        type: 'object',
        properties: {
          "key": {
            "type": "string",
            "enum": [
              "summary",
              "metrics",
              "alarms"
            ]
          },
          "time_range": {
            "type": "string",
            "enum": [
              "today",
              "last_hour",
              "last_day",
              "last_week",
              "last_month"
            ]
          }
        },
        "required": ["key", "time_range"]
      }
    }
  end

  def execute(arguments)

    $logger.info "Getting bot health monitoring information: #{arguments.ai}"

    # The default time range is the last hour, with a period of one minute.
    seconds_ago = 60 * 60
    period      = 60

    case arguments['time_range']
    when 'last_hour'
      seconds_ago = 60 * 60            # 1 hour in seconds
      # The default period is 60 seconds.
    when 'last_day'
      seconds_ago = 60 * 60 * 24       # 1 day in seconds
      period      = 60 * 60
    when 'last_week'
      seconds_ago = 60 * 60 * 24 * 7   # 1 week in seconds
      period      = 60 * 60 * 24
    when 'last_month'
      seconds_ago = 60 * 60 * 24 * 30  # 1 month in seconds
      period      = 60 * 60 * 24
    #when 'today'
      # TODO: Compute this time range.
      # It will depend on the current time zone.
    end

    time_ago_string = format_time_ago_string(seconds_ago: seconds_ago)

    case arguments['key']
    when 'summary'

      {
        "summary":
          [
            "Number of Slack messages that I sent in the last #{time_ago_string}: #{@@cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'Slack Messages Sent',
              time_window: seconds_ago,
              period: period)}",
            "Estimated total cost of the OpenAI tokens that I used in the last #{time_ago_string}: USD $#{@@cloudwatch_metrics.get_metric_sum_over_time(
              metric_name: 'OpenAI Total Token Cost',
              time_window: seconds_ago,
              period: period).round(2)}"
          ].join(' '),

        "attachments": "CloudWatch metric widget image attached."
      }
    when 'metrics'
      
      attach_metric_widget_image(seconds_ago: seconds_ago)

      {
        "metrics": [

          # Activity metrics.

          {
            "Number of Slack Messages Received in the last #{time_ago_string}":
              @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Received',
                time_window: seconds_ago,
                period: period)
          },
          {
            "Number of Slack Messages Sent in the last #{time_ago_string}":
            @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Sent',
                time_window: seconds_ago,
                period: period)
          },  
          {
            "Number of Slack Messages Updated in the last #{time_ago_string}":
            @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Slack Messages Updated',
                time_window: seconds_ago,
                period: period)
          },  
          {
            "Number of Open AI Chat API Responses in the last #{time_ago_string}":
            @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Open AI Chat API Responses',
                time_window: seconds_ago,
                period: period)
          },
          {
            "Number of Function Responses in the last #{time_ago_string}":
            @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'Function Responses',
                time_window: seconds_ago,
                period: period)
          },

          # OpenAI token usage metrics.

          {
            "Number of OpenAI prompt tokens used in the last #{time_ago_string}":
              @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Prompt Token Usage',
                time_window: seconds_ago,
                period: period)
          },
          {
            "Number of OpenAI completion tokens used in the last #{time_ago_string}":
              @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Completion Token Usage',
                time_window: seconds_ago,
                period: period)
          },
          {
            "Number of OpenAI total tokens used in the last #{time_ago_string}":
              @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Total Token Usage',
                time_window: seconds_ago,
                period: period)
          },

          # OpenAI token cost metrics.
          
          {
            "OpenAI prompt token cost in the last #{time_ago_string} in dollars":
              'USD $' + @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Input Token Cost',
                time_window: seconds_ago,
                period: period).round(2).to_s
          },
          {
            "OpenAI completion tokens cost in the last #{time_ago_string} in dollars":
            'USD $' + @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Output Token Cost',
                time_window: seconds_ago,
                period: period).round(2).to_s
          },
          {
            "OpenAI total tokens cost in the last #{time_ago_string} in dollars":
            'USD $' + @@cloudwatch_metrics.get_metric_sum_over_time(
                metric_name: 'OpenAI Total Token Cost',
                time_window: seconds_ago,
                period: period).round(2).to_s
          }
          
        ]
      }
    end.tap do |result|
      $logger.debug "Result: #{result.ai}"
    end
  end

  def attach_metric_widget_image(seconds_ago:)
    environment = ENV['ENVIRONMENT'] || 'development'
    namespace = ENV['AWS_RESOURCE_NAME'].gsub(/ /,'')
    region = ENV['AWS_REGION'] || 'us-east-1'

    # Get the current timestamp in UTC
    current_time = Time.now.utc
    
    # Calculate the start time by subtracting the seconds_ago value from the current timestamp
    start_time = current_time - seconds_ago
    
    # Format the start and end times in the ISO 8601 format
    start_time_iso = start_time.iso8601
    end_time_iso = current_time.iso8601

    metric_widget_json = <<-JSON
      {
        "title":
          "Activity for the last #{format_time_ago_string(seconds_ago: seconds_ago)}",
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
        "start": "#{start_time_iso}",
        "end": "#{end_time_iso}",
        "stat": "Sum",
        "liveData": true,
        "width": 1200,
        "height": 800,
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
      @@cloudwatch_metrics.get_cloudwatch_metric_widget_image(
        metric_widget_json: metric_widget_json)
    $logger.debug "Generated metric image at file path: #{metric_image_file_path}"

    @response_channel.attach_file(
      # Used to ensure that the file is only attached once.
      attachment_key: 'metric_image',
      file_path: metric_image_file_path,
      file_name: 'metric_image.png'
    )
  end

  def format_time_ago_string(seconds_ago:)
    ActiveSupport::Duration.build(seconds_ago).inspect
  end

end