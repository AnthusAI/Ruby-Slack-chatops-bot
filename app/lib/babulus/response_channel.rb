require 'logger'
require 'mime/types'
require 'babulus'

module Babulus

class ResponseChannel < SlackChannel

  def initialize(
    channel:,
    original_message_timestamp:,
    slack_access_token:
  )

    super(channel: channel, slack_access_token: slack_access_token)

    @original_message_timestamp = original_message_timestamp
    
    @status_emojis = Configuration::StatusEmojis.new.get
    $logger.info("Status emojis are #{@status_emojis ? 'enabled' : 'disabled'}")
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

end # module Babulus