require 'logger'
require_relative 'cloudwatch_metrics'
require_relative 'configuration_setting'

class ResponseChannel

  def initialize(
    original_message_timestamp:,
    slack_access_token:,
    channel:
  )

    @cloudwatch_metrics = CloudWatchMetrics.new

    @slack_access_token = slack_access_token
    @channel = channel
    @original_message_timestamp = original_message_timestamp
    
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

    @response_message_timestamp = response['ts']
  end
  
  def update_message(text:)
    if @response_message_timestamp.nil?
      $logger.debug("Sending new message since there is no existing message to update.")
      return send_message(text: text)
    end

    $logger.debug(
    "Updating existing message from timestamp #{@response_message_timestamp} in Slack: #{text}")
  
    client = Slack::Web::Client.new(token: @slack_access_token)
  
    client.chat_update(
      channel: @channel,
      text: text,
      ts: @response_message_timestamp # Timestamp of the message to update
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
    unless @status_emojis
      $logger.debug("Not adding reaction emoji #{emoji} because status emojis are disabled.")
      return
    end

    $logger.info("Adding reaction emoji to original message: #{emoji}")

    client = Slack::Web::Client.new(token: @slack_access_token)

    client.reactions_add(
      channel: @channel,
      name: emoji,
      timestamp: @original_message_timestamp # Timestamp of the original message to react to
    ).tap do |response|
      $logger.info("Added reaction to original message: #{response.inspect}")
      @cloudwatch_metrics.send_metric_reading(
        metric_name: "Slack Reactions Sent",
        value: 1,
        unit: 'Count'
      )
    end

    rescue Slack::Web::Api::Errors::AlreadyReacted => e
      $logger.info("Ignoring error adding reaction to original message: #{e.message}")
  end

end