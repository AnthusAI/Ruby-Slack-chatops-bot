require_relative 'spec_helper'
require_relative 'slack_events_api'

ENV['SLACK_APP_ID'] = 'A05D7UH7GHH'

module Babulus

describe 'SlackEventsAPIHandler' do
  let(:channel_id) { 'C01HYM7S9PD' }
  let(:bot_id) { 'U01J218HDYS' }
  let(:user1_id) { 'U01HYM5LRMQ' }
  let(:user2_id) { 'U01HZ9PA37T' }
  let(:bot_message) { 'Hello, I am a bot.' }
  let(:user1_message) { 'Hello, bot.' }
  let(:user2_message) { 'Hello, everyone.' }
  let(:kv_store) { instance_double(KeyValueStore) }
  let(:bot_id_cache_response) { instance_double(Aws::DynamoDB::Types::GetItemOutput) }
  let(:ssm_client) { instance_double(Aws::SSM::Client) }
  let(:secretsmanager_client) { instance_double(Aws::SecretsManager::Client) }
  let(:cloudwatch_metrics) { instance_double(CloudWatchMetrics) }

  before do
    allow(KeyValueStore).to receive(:new).and_return(kv_store)
    allow(kv_store).to receive(:get).with(key: 'app_id').and_return('A05D7UH7GHH')
    allow(kv_store).to receive(:get).with(key: 'user_id').and_return('U05D815D3PD')
    allow(kv_store).to receive(:get).with(key: 'access_token').and_return('xoxb-your-token')
    
    allow(Aws::SecretsManager::Client).to receive(:new).
      and_return(secretsmanager_client)
    allow(secretsmanager_client).to receive(:get_secret_value).with(
        secret_id: 'Babulus-slack-app-access-token-development'
      ).and_return(
        instance_double(
          'Aws::SecretsManager::Types::GetSecretValueResponse',
          secret_string: 'DEADBEEF')
      )

    allow(cloudwatch_metrics).to receive(:send_metric_reading)
    allow(CloudWatchMetrics).to receive(:new).and_return(cloudwatch_metrics)
    
    stub_request(:get, 'https://slack.com/api/bots.info?bot=U01J218HDYS')
      .to_return(
        status: 200,
        body: {
          "ok": true,
          "bot": {
              "id": "B123456",
              "deleted": false,
              "name": "beforebot",
              "updated": 1449272004,
              "app_id": "A123456",
              "user_id": "U123456",
              "icons": {
                  "image_36": "https://...",
                  "image_48": "https://...",
                  "image_72": "https://..."
              }
          }
        }.to_json,
        headers: {}
      )
    stub_request(:post, "https://slack.com/api/conversations.history")
      .to_return(
        status: 200,
        body: {
          "ok" => true,
          "messages" => [
            { "type" => "message", "user" => bot_id, "text" => bot_message },
            { "type" => "message", "user" => user1_id, "text" => user1_message },
            { "type" => "message", "user" => user2_id, "text" => user2_message }
          ]
        }.to_json,
        headers: {}
      )
    stub_request(:get, "https://slack.com/api/users.profile.get").
      to_return(
        status: 200,
        body: {
          "ok": true,
          "profile": {
              "title": "Bot",
              "real_name": "Bot Botly",
              "real_name_normalized": "Bot Botly",
              "display_name": "bot",
              "display_name_normalized": "bot",
              "status_text": "Watching electrons spin",
              "first_name": "bot",
              "last_name": "botly",
              "bot_id": bot_id
          }
        }.to_json,
        headers: {}
      )
    stub_request(:get, "https://slack.com/api/users.profile.get?user=U01J218HDYS").
          to_return(
            status: 200,
            body: {
              "ok": true,
              "profile": {
                  "title": "Head of Coffee Production",
                  "real_name": "John Smith",
                  "real_name_normalized": "John Smith",
                  "display_name": "john",
                  "display_name_normalized": "john",
                  "status_text": "Watching cold brew steep",
                  "first_name": "john",
                  "last_name": "smith"
              }
            }.to_json,
            headers: {}
          )
    stub_request(:get, 'https://slack.com/api/users.profile.get?user=U01HYM5LRMQ')
      .to_return(
        status: 200,
        body: {
          "ok": true,
          "profile": {
            "title": 'Assitant to the Head of Coffee Production',
            "real_name": 'Dale Smith',
            "real_name_normalized": 'Dale Smith',
            "display_name": 'dale',
            "display_name_normalized": 'dale',
            "status_text": 'Watching someone watch cold brew steep',
            "first_name": 'dale',
            "last_name": 'smith'
          }
        }.to_json,
        headers: {}
      )
    stub_request(:get, 'https://slack.com/api/users.profile.get?user=U01HZ9PA37T')
          .to_return(
            status: 200,
            body: {
              "ok": true,
              "profile": {
                "title": 'Assistant to the Assistant of the Head of Coffee Production',
                "real_name": 'Daryl Smith',
                "real_name_normalized": 'Daryl Smith',
                "display_name": 'daryl',
                "display_name_normalized": 'daryl',
                "status_text": 'Watching someone watch someone watch cold brew steep',
                "first_name": 'daryl',
                "last_name": 'smith'
              }
            }.to_json,
            headers: {}
          )
    stub_request(:post, "https://slack.com/api/chat.postMessage")
      .to_return(
        status: 200,
        body: {
          "ok" => true,
          "channel" => "C01HYM7S9PD",
          "ts" => "1627300000.000100",
          "message" => {
            "bot_id" => "B01J218HDYS",
            "type" => "message",
            "text" => "Hello, world!",
            "user" => "U01HYM5LRMQ",
            "ts" => "1627300000.000100",
            "team" => "T01HYM5LRMQ",
            "bot_profile" => {
              "id" => "B01J218HDYS",
              "deleted" => false,
              "name" => "openai-chat-bot",
              "updated" => 1627300000,
              "app_id" => "A01J218HDYS",
              "icons" => {
                "image_36" => "https://a.slack-edge.com/80588/img/plugins/app/bot_36.png",
                "image_48" => "https://a.slack-edge.com/80588/img/plugins/app/bot_48.png",
                "image_72" => "https://a.slack-edge.com/80588/img/plugins/app/service_72.png"
              },
              "team_id" => "T01HYM5LRMQ"
            }
          }
        }.to_json,
        headers: {}
      )

    allow(KeyValueStore).to receive(:new).and_return(kv_store)
    allow(bot_id_cache_response).to receive(:item).and_return({
      'key' => 'bot_id',
      'value' => bot_id
    })

    allow(kv_store).to receive(:get).
      with(key: 'user_profiles/U01J218HDYS').
      and_return({
        'display_name' => 'john',
        'display_name_normalized' => 'john',
        'first_name' => 'john',
        'last_name' => 'smith',
        'real_name' => 'John Smith',
        'real_name_normalized' => 'John Smith',
        'status_text' => 'Watching cold brew steep',
        'title' => 'Head of Coffee Production'
      })
    allow(kv_store).to receive(:get).
      with(key: 'user_profiles/U01HYM5LRMQ').
      and_return({
        'display_name' => 'dale',
        'display_name_normalized' => 'dale',
        'first_name' => 'dale',
        'last_name' => 'smith',
        'real_name' => 'Dale Smith',
        'real_name_normalized' => 'Dale Smith',
        'status_text' => 'Watching someone watch cold brew steep',
        'title' => 'Assistant to the Head of Coffee Production'
      })
    allow(kv_store).to receive(:get).
      with(key: 'user_profiles/U01HZ9PA37T').
      and_return({
        'display_name' => 'daryl',
        'display_name_normalized' => 'daryl',
        'first_name' => 'daryl',
        'last_name' => 'smith',
        'real_name' => 'Daryl Smith',
        'real_name_normalized' => 'Daryl Smith',
        'status_text' => 'Watching someone watch someone watch cold brew steep',
        'title' => 'Assistant to the Assistant of the Head of Coffee Production'
      })
  end

  let(:url_verification_event) do
    {
      'token' => 'Jhj5dZrVaK7ZwHHjRyZWjbDl',
      'challenge' => '3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P',
      'type' => 'url_verification'
    }.to_json
  end

  let(:message_event) do
    {
      'token' => 'Xji60p7xlJYZv16D8XqvtPdu',
      'team_id' => 'T38A9EMB4',
      'api_app_id' => 'A05D7UH7GHH',
      'event' => {
        'client_msg_id' => 'dc5f9729-3bef-454f-9a59-51f3e76b5cc8',
        'type' => 'message',
        'text' => 'Test.',
        'user' => 'U38CHGBLL',
        'ts' => '1687226301.070299',
        'team' => 'T38A9EMB4',
        'channel' => 'D05DXTTARMW',
        'event_ts' => '1687226301.070299'
      },
      'type' => 'event_callback',
      'event_id' => 'Ev05D8RGPFQA',
      'event_time' => 1_687_226_301,
      'event_context' => '4-eyJldCI6Im1lc3NhZ2UiLCJ0aWQiOiJUMzhBOUVNQjQiLCJhaWQiOiJBMDVEN1VIN0dISCIsImNpZCI6IkQwNURYVFRBUk1XIn0'
    }.to_json
  end

  let(:app_mention_event) do
    {
      "token" => "ZZZZZZWSxiZZZ2yIvs3peJ",
      "team_id" => "T061EG9R6",
      "api_app_id" => "A0MDYCDME",
      "event" => {
          "type" => "app_mention",
          "user" => "W021FGA1Z",
          "text" => "You can count on <@U0LAN0Z89> for an honorable mention.",
          "ts" => "1515449483.000108",
          "channel" => "C123ABC456",
          "event_ts" => "1515449483000108"
      },
      "type" => "event_callback",
      "event_id" => "Ev0MDYHUEL",
      "event_time" => 1515449483000108,
      "authed_users" => [
          "U0LAN0Z89"
      ]
    }.to_json
  end

  let(:direct_message_event) do
    {
        "token" => "one-long-verification-token",
        "team_id" => "T061EG9R6",
        "api_app_id" => "A0PNCHHK2",
        "event" => {
            "type" => "message",
            "channel" => "D024BE91L",
            "user" => "U2147483697",
            "text" => "Hello hello can you hear me?",
            "ts" => "1355517523.000005",
            "event_ts" => "1355517523.000005",
            "channel_type" => "im"
        },
        "type" => "event_callback",
        "authed_teams" => [
            "T061EG9R6"
        ],
        "event_id" => "Ev0PV52K21",
        "event_time" => 1355517523
    }.to_json
  end

  describe '#dispatch' do

    it 'should call url_confirmation for URL verification events' do
      slack_events_api = SlackEventsAPIHandler.new(url_verification_event)
      expect(slack_events_api).to receive(:url_confirmation)
      slack_events_api.send(:dispatch)
    end

    it 'should call message for message events' do
      slack_events_api = SlackEventsAPIHandler.new(message_event)
      expect(slack_events_api).to receive(:message)
      slack_events_api.send(:dispatch)
    end

    it 'should call app_mention for app_mention events' do
      slack_events_api = SlackEventsAPIHandler.new(app_mention_event)
      expect(slack_events_api).to receive(:message)
      slack_events_api.send(:dispatch)
    end
    
  end

  describe '#url_verification' do

    it 'should respond to URL verification events with the challenge' do
      slack_events_api = SlackEventsAPIHandler.new(url_verification_event)
      expect(slack_events_api.dispatch).to eq('3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P')
    end

  end

  describe '#message' do

    it 'should handle message events' do
      slack_events_api = SlackEventsAPIHandler.new(message_event)
      slack_events_api.dispatch
    end

  end

  describe '#event_is_from_me?' do

    it 'returns true when the event is from the app' do
      massaged_event = JSON.parse(message_event)
      massaged_event['event']['app_id'] = 'A05D7UH7GHH'

      slack_events_api = SlackEventsAPIHandler.new(massaged_event.to_json)

      expect(slack_events_api.send(:event_is_from_me?)).to eq(true)
    end

    it 'returns false when the event is not from the app' do
      massaged_event = JSON.parse(message_event)
      massaged_event['event']['app_id'] = 'SomeOtherAppID'

      slack_events_api = SlackEventsAPIHandler.new(massaged_event.to_json)

      expect(slack_events_api.send(:event_is_from_me?)).to eq(false)
    end

  end

  describe '#event_is_direct_message?' do

    it 'returns true when the event is a direct message' do
      slack_events_api = SlackEventsAPIHandler.new(direct_message_event)

      expect(slack_events_api.send(:event_is_direct_message?)).to eq(true)
    end

    it 'returns false when the event is not a direct message' do
      slack_events_api = SlackEventsAPIHandler.new(message_event)

      expect(slack_events_api.send(:event_is_direct_message?)).to eq(false)
    end

  end

  describe '#get_conversation_history' do

    let (:conversation_history) { instance_double(SlackConversationHistory) }
  
    it 'fetches conversation history from a channel' do
      allow(SlackConversationHistory).to receive(:new). 
        and_return(conversation_history)
      allow(conversation_history).to receive(:fetch_from_slack)
      allow(conversation_history).to receive(:get_recent_messages).
        and_return([
          { "channelId" => channel_id,
            "ts" => 1627300000,
            "userId" => bot_id,   "message" => bot_message },
          { "channelId" => channel_id,
            "ts" => 1627300001,
            "userId" => user1_id, "message" => user1_message },
          { "channelId" => channel_id,
            "ts" => 1627300002,
            "userId" => user2_id, "message" => user2_message }
        ])

      history = SlackEventsAPIHandler.new(message_event.to_json).
        get_conversation_history(channel_id)
      expect(history.length).to eq(3)
      expect(history[0]['userId']).to eq(bot_id)
      expect(history[0]['message']).to eq(bot_message)
      expect(history[1]['userId']).to eq(user1_id)
      expect(history[1]['message']).to eq(user1_message)
      expect(history[2]['userId']).to eq(user2_id)
      expect(history[2]['message']).to eq(user2_message)
    end
  end
  
  describe '#get_user_profile' do
    let(:event) { message_event }
    let(:bot) { SlackEventsAPIHandler.new(event.to_json) }
    let(:user_id) { 'U01J218HDYS' }

    it 'returns the user profile' do
      expect(bot.get_user_profile(user_id))
        .to eq({
          'display_name' => 'john',
          'display_name_normalized' => 'john',
          'first_name' => 'john',
          'last_name' => 'smith',
          'real_name' => 'John Smith',
          'real_name_normalized' => 'John Smith',
          'status_text' => 'Watching cold brew steep',
          'title' => 'Head of Coffee Production'
        })
    end

  end
  
end

end # module Babulus