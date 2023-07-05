require_relative '../lib/spec_helper.rb'
require_relative '../lib/function.rb'
require_relative 'get_bot_monitoring_information.rb'

ENV['OPEN_AI_CHAT_API_METRIC'] = 'SlackBot::Open AI Chat API Responses - development'
ENV['FUNCTION_RESPONSES_METRIC'] = 'SlackBot::Function Responses - development'

WebMock.allow_net_connect!

RSpec.describe GetBotMonitoringInformation do
  describe '.execute' do
    it 'gets metric statistics' do
      result = GetBotMonitoringInformation.new.execute({})

      puts "Result:\n#{result.ai}"
    end
  end
end
