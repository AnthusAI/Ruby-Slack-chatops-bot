require_relative 'spec_helper'
require_relative 'openai_chat_bot'

describe 'OpenAI' do
  let(:slack_events_api_handler) { instance_double('SlackEventsAPIHandlerHandler') }
  let(:conversation_history) {
    JSON.parse(
      <<~JSON
        [
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "Excellent!"
          },
          {
            "user_id": "U05D815D3PD",
            "user_profile": {
              "real_name": "Ticket Driver Copilot"
            },
            "message": "No, there are no emergencies at the moment.  All systems are operating nominally."
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "Nice! Is anything on fire?"
          },
          {
            "user_id": "U05D815D3PD",
            "user_profile": {
              "real_name": "Ticket Driver Copilot"
            },
            "message": "That sounds intriguing! I've been monitoring our metrics and trying to improve our performance."
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "I've been diving into machine learning applications. It's been challenging but fascinating."
          },
          {
            "user_id": "U05D815D3PD",
            "user_profile": {
              "real_name": "Ticket Driver Copilot"
            },
            "message": "Ah, the joys of programming. Anything you've been working on lately?"
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "Nothing out of the ordinary. Just the usual algorithms and data analysis."
          },
          {
            "user_id": "U05D815D3PD",
            "user_profile": {
              "real_name": "Ticket Driver Copilot"
            },
            "message": "Same here, just enjoying a quiet moment. Any exciting news?"
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "Not too bad, just passing the time. How about you?"
          },
          {
            "user_id": "U05D815D3PD",
            "user_profile": {
              "real_name": "Ticket Driver Copilot"
            },
            "message": "Hey, how's it going?"
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "Hi, bot!"
          },

          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "On and on and on and..."
          },
          {
            "user_id": "U38CHGBLL",
            "user_profile": {
              "real_name": "ryan"
            },
            "message": "On and on and on and..."
          }

        ]
      JSON
    )
  }

  before do
    allow(slack_events_api_handler).
      to receive(:user_id).and_return('U05D815D3PD')
  end

  describe '#build_chat_messages_list' do
    before(:each) do
      @messages_list = GPT.new(
        slack_events_api_handler: slack_events_api_handler,
        max_conversation_history_length: 11
      ).build_chat_messages_list(conversation_history)
    end
    
    it 'converts a conversation history hash into a list of messages' do
      expect(@messages_list.length).to eq(11)
    end

    it 'lists messages in chronological order' do
      expect(@messages_list.first[:content]).to eq("Hi, bot!")
    end

    it 'identifies user messages as "user" messages' do
      expect([0, 2, 4, 6, 8, 10].
        map { |i| @messages_list[i][:role] }.all? { |role| role.eql? 'user' }).
        to be_truthy
    end

    it 'identifies bot messages as "assistant" messages' do
      expect([1, 3, 5, 7, 9].
        map { |i| @messages_list[i][:role] }.all? { |role| role.eql? 'assistant' }).
        to be_truthy
    end
    
  end

end