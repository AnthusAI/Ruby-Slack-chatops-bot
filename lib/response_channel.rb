require 'logger'
require_relative 'cloudwatch_metrics'
require_relative 'configuration_setting'

class ResponseChannel

  def initialize(slack_access_token:, channel:)
    @cloudwatch_metrics = CloudWatchMetrics.new

    @slack_access_token = slack_access_token
    @channel = channel
    
    @status_emojis = Configuration::StatusEmojis.new.get
    $logger.info("Status emojis are #{@status_emojis ? 'enabled' : 'disabled'}")
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
    if @timestamp.nil?
      $logger.info("Sending new message since there is no existing message to update.")
      return send_message(text: text)
    end

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

  def update_status_emoji(emoji:)
    if @status_emojis
      $logger.info("Updating status emoji to #{emoji}")

      if @timestamp.nil?
        send_message(text: emoji)
      else
        update_message(text: emoji)
      end
      
    else
      $logger.info("Not updating status emoji to #{emoji} because status emojis are disabled.")
    end
  end

end