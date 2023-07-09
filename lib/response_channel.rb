require 'logger'
require_relative 'cloudwatch_metrics'

class ResponseChannel

  def initialize(slack_access_token:, channel:)
    @cloudwatch_metrics = CloudWatchMetrics.new

    @slack_access_token = slack_access_token
    @channel = channel
  end

  def send_message(text:)
    $logger.debug("Sending message to Slack on channel #{@channel}: \"#{text}\"")
    
    client = Slack::Web::Client.new(token: @slack_access_token)
    
    response =
      client.chat_postMessage(channel: @channel, text: text).
        tap do |response|
          $logger.info(
            "Sent message to Slack on channel #{@channel}: #{response.inspect}")
          @cloudwatch_metrics.send_metric_reading(
            metric_name: "Slack Messages Sent",
            value: 1,
            unit: 'Count'
          )
        end

    @timestamp = response['ts']
  end
  
  def update_message(text:)
    $logger.debug(
      "Updating existing message from timestamp #{@timestamp} in Slack: #{text}")
  
    client = Slack::Web::Client.new(token: @slack_access_token)
  
    client.chat_update(
      channel: @channel,
      text: text,
      ts: @timestamp # Timestamp of the message to update
    ).tap do |response|
      $logger.debug("Updated message in Slack: #{response.inspect}")
      @cloudwatch_metrics.send_metric_reading(
        metric_name: "Slack Messages Updated",
        value: 1,
        unit: 'Count'
      )
    end
  end

end