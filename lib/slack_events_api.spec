require_relative 'spec_helper'
require_relative 'slack_events_api'

describe 'SlackEventsAPIHandler' do
  before do
    allow_any_instance_of(Aws::SSM::Client).to receive(:get_parameter) do |_, args|
      if args[:name].include?('app_id')
        double(parameter: double(value: 'A05D7UH7GHH'))
      elsif args[:name].include?('user_id')
        double(parameter: double(value: 'U05D815D3PD'))
      elsif args[:name].include?('access_token')
        double(parameter: double(value: 'xoxb-your-token'))
      end
    end
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
        'event_ts' => '1687226301.070299',
        'channel_type' => 'im'
      },
      'type' => 'event_callback',
      'event_id' => 'Ev05D8RGPFQA',
      'event_time' => 1_687_226_301,
      'event_context' => '4-eyJldCI6Im1lc3NhZ2UiLCJ0aWQiOiJUMzhBOUVNQjQiLCJhaWQiOiJBMDVEN1VIN0dISCIsImNpZCI6IkQwNURYVFRBUk1XIn0'
    }.to_json
  end

  let(:app_mention_event) do
    {
      "token": "ZZZZZZWSxiZZZ2yIvs3peJ",
      "team_id": "T061EG9R6",
      "api_app_id": "A0MDYCDME",
      "event": {
          "type": "app_mention",
          "user": "W021FGA1Z",
          "text": "You can count on <@U0LAN0Z89> for an honorable mention.",
          "ts": "1515449483.000108",
          "channel": "C123ABC456",
          "event_ts": "1515449483000108"
      },
      "type": "event_callback",
      "event_id": "Ev0MDYHUEL",
      "event_time": 1515449483000108,
      "authed_users": [
          "U0LAN0Z89"
      ]
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
      expect(slack_events_api).to receive(:app_mention)
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

    it 'should hangle message events' do
      slack_events_api = SlackEventsAPIHandler.new(message_event)
      slack_events_api.dispatch
    end

  end

  describe '#is_event_from_me?' do

    it 'returns true when the event is from the app' do
      event = JSON.parse(message_event)
      event['event']['app_id'] = 'A05D7UH7GHH'

      slack_events_api = SlackEventsAPIHandler.new(event.to_json)

      expect(slack_events_api.send(:is_event_from_me?)).to eq(true)
    end

    it 'returns false when the event is not from the app' do
      event = JSON.parse(message_event)
      event['event']['app_id'] = 'SomeOtherAppID'

      slack_events_api = SlackEventsAPIHandler.new(event.to_json)

      expect(slack_events_api.send(:is_event_from_me?)).to eq(false)
    end
  end

  describe '#get_conversation_history' do
    let(:channel_id) { 'C01HYM7S9PD' }
    let(:bot_id) { 'U01J218HDYS' }
    let(:user1_id) { 'U01HYM5LRMQ' }
    let(:user2_id) { 'U01HZ9PA37T' }
    let(:bot_message) { 'Hello, I am a bot.' }
    let(:user1_message) { 'Hello, bot.' }
    let(:user2_message) { 'Hello, everyone.' }
    let(:http) { instance_double('Net::HTTP') }
    let(:response) { instance_double('Net::HTTPResponse', body: {
      "ok" => true,
      "messages" => [
        { "type" => "message", "user" => bot_id, "text" => bot_message },
        { "type" => "message", "user" => user1_id, "text" => user1_message },
        { "type" => "message", "user" => user2_id, "text" => user2_message }
      ]
    }.to_json) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=).with(true).and_return(true)
      allow(http).to receive(:request).and_return(response)
    end
  
    it 'fetches conversation history from a channel' do
      event = JSON.parse(message_event)
      history = SlackEventsAPIHandler.new(event.to_json).
        send(:get_conversation_history, channel_id)
      expect(history.length).to eq(3)
      expect(history[0]['user_id']).to eq(bot_id)
      expect(history[0]['message']).to eq(bot_message)
      expect(history[1]['user_id']).to eq(user1_id)
      expect(history[1]['message']).to eq(user1_message)
      expect(history[2]['user_id']).to eq(user2_id)
      expect(history[2]['message']).to eq(user2_message)
    end
  end
  
  describe '#get_user_profile' do
    let(:event) { JSON.parse(message_event) }
    let(:bot) { SlackEventsAPIHandler.new(event.to_json) }
    let(:user_id) { 'U38CHGBLL' }
    let(:http) { instance_double(Net::HTTP) }
    let(:response) { instance_double(Net::HTTPResponse) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:request).and_return(response)
    end

    context 'when the API call is successful' do
      before do
        allow(response).to receive(:body).and_return({
          ok: true,
          profile: { 
            first_name: 'John',
            last_name: 'Doe',
            real_name: 'John Doe',
            email: 'john.doe@example.com',
            phone: '1234567890',
            title: 'Engineer'
          }
        }.to_json)
      end

      it 'returns the user profile' do
        expect(bot.get_user_profile(user_id))
          .to eq({
            'first_name' => 'John',
            'last_name' => 'Doe',
            'real_name' => 'John Doe',
            'email' => 'john.doe@example.com',
            'phone' => '1234567890',
            'title' => 'Engineer'
        })
      end

      it 'caches the user profile' do
        bot.get_user_profile(user_id) # First time, API call is made
        bot.get_user_profile(user_id) # Second time, no API call due to cache

        # Expect the HTTP request to have been made only once
        expect(http).to have_received(:request).once
      end
    end

    context 'when the API call fails' do
      it 'returns nil and logs an error' do
        allow(response).to receive(:body).and_return({
          ok: false,
          error: 'user_not_found'
        }.to_json)

        expect(bot.get_user_profile(user_id)).to be_nil
      end
    end
  end
  
end