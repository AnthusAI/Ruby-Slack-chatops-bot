require 'logger'
require 'mime/types'
require 'babulus'

module Babulus

class SlackChannel

  def initialize(
    channel:,
    slack_access_token:
  )

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
            "Sent message to Slack on channel #{@channel}:\n#{JSON.pretty_generate(response)}")
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
  ensure
    # Upload any pending file attachments, now that the message has been
    # posted first.
    upload_pending_file_attachments
  end

  # Accept an attached file and remember it later so that we can include
  # it in the response message.
  def attach_file(
    attachment_key:,
    file_path:,
    file_name:nil)

    $logger.info("Attaching file #{file_name} to Slack on channel #{@channel}")

    @attachments ||= {}
    @attachments[attachment_key] = {
      file_path: file_path,
      file_name: file_name
    }
  end

  def upload_pending_file_attachments
    $logger.info("Uploading pending file attachments to Slack on channel #{@channel}")
    return if @attachments.nil?

    # Upload each file and remove the attachment from the list.
    @attachments.keys.each do |attachment_key|
      $logger.debug("Uploading file attachment #{attachment_key} to Slack on channel #{@channel}")
      attachment = @attachments.delete(attachment_key)
      upload_file(
        file_path: attachment[:file_path],
        file_name: attachment[:file_name]
      )
    end
  end

  def upload_file(file_path: , file_name:nil)
    file_name ||= File.basename(file_path)
    $logger.info("Uploading file #{file_name} to Slack on channel #{@channel}")

    content_type = MIME::Types.type_for(file_path).first.content_type
    $logger.info("Content type #{content_type}")

    client = Slack::Web::Client.new(token: @slack_access_token)
  
    client.files_upload(
      channels: @channel,
      file: Faraday::UploadIO.new(file_path, content_type),
      title: file_name
    )
  end

end

end # module Babulus