require_relative 'helper'
require 'aws-sdk-cloudwatch'
require 'active_support/core_ext/integer/time'

class CloudWatchMetrics

  def initialize
    @cloudwatch = Aws::CloudWatch::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1')
    @namespace = ENV['AWS_RESOURCE_NAME'].gsub(/ /,'')
  end

  def send_metric_reading(value:, metric_name:, unit:'None', dimensions: [])
    @cloudwatch.put_metric_data({
      namespace: @namespace,
      metric_data: [
        {
          metric_name: metric_name,
          dimensions: dimensions <<
          {
            name: 'Environment',
            value: ENV['ENVIRONMENT'],
          },
          timestamp: Time.now,
          value: value.to_f,
          unit: unit
        },
      ]
    })
  end

  def get_metric_sum_over_time(metric_name:, time_window: 3600)
    # Format time_window as a human-readable string.
    time_window_string = ActiveSupport::Duration.build(time_window).inspect

    $logger.info "Getting average of metric #{metric_name} over the last #{time_window_string}."
  
    response = @cloudwatch.get_metric_statistics({
      # The namespace of the metric, in this case, the value before "::"
      namespace: @namespace,
      dimensions: [
        {
          name: "Environment",
          value: ENV['ENVIRONMENT'],
        }
      ],
      # The name of the metric, in this case, the value after "::"
      metric_name: metric_name,
      # The timestamp that determines the first datapoint to return.
      start_time: Time.now - time_window,
      # The timestamp that determines the last datapoint to return.
      end_time: Time.now,
      # The granularity, in seconds.
      period: 60,
      # The metric statistics.
      statistics: ["Sum"],
    })

    response.datapoints.map(&:sum).sum
  end

  # This gets a CloudWatch metric widget image and returns the full path of the
  # temporary file where the image is stored.
  def get_cloudwatch_metric_widget_image(metric_widget_json:)
    image_data = @cloudwatch.get_metric_widget_image(
      metric_widget: metric_widget_json,
      output_format: 'png'
    ).metric_widget_image
  
    # Create a Tempfile object. This creates a real file in a temporary directory.
    temp_file = Tempfile.new(['metric_widget_image', '.png'])
  
    # Write the image data to the file and close it.
    temp_file.binmode  # Set file to binary mode
    temp_file.write(image_data)
    temp_file.close
  
    # Return the full path of the temporary file.
    temp_file.path
  end

end