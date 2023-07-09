require_relative 'spec_helper.rb'
require_relative 'configuration_setting.rb'

ENV['ENVIRONMENT'] = 'development'
ENV['AWS_RESOURCE_NAME'] = 'Slack Bot'

WebMock.allow_net_connect!

RSpec.describe Configuration::Setting do

  let(:table_name) { 'slack-bot-key-value-store-development' }
  
  before do
    ENV['KEY_VALUE_STORE_TABLE'] = table_name
  end

  describe '.set' do

    it 'sets a configuration setting value' do
      new_setting = Configuration::Setting.
        find(key: 'foo').set(value: 'bar')

      expect(new_setting).to eq({
        key: 'foo',
        value: 'bar'
      })
    end

    it 'sets the computed model configuration setting value' do
      new_setting = Configuration::Setting.
        find(key: 'model').set(value: 'gpt-3.5')
    
      expect(new_setting).to eq({
        key: 'model',
        value: 'gpt-3.5-turbo-0613'
      })
    end

    it 'sets the computed model temperature setting value' do
      new_setting = Configuration::Setting.
        find(key: 'temperature').set(value: 'low')
    
      expect(new_setting).to eq({
        key: 'temperature',
        value: 0.5
      })
    end

  end

end
