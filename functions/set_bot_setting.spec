require_relative '../lib/spec_helper.rb'
require_relative 'set_bot_setting.rb'

ENV['ENVIRONMENT'] = 'development'
ENV['AWS_RESOURCE_NAME'] = 'Slack Bot'

WebMock.allow_net_connect!

RSpec.describe SetBotSetting do
  describe '.definition' do
    it 'returns a definition' do
      definition = SetBotSetting.new.definition

      puts "Definition:\n#{definition.ai}"

      expect(definition[:name]).to eq 'set_bot_setting'
    end
  end

  describe '.execute' do
    xit 'sets metric statistics' do
    end
  end
end
