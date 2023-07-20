require 'babulus/spec_helper'

require_relative 'get_bot_setting.rb'
require 'aws-sdk-dynamodb'

RSpec.describe GetBotSetting do
  let(:table_name) { 'TestTable' }
  let(:key_value_store) { instance_double(KeyValueStore) }
  let(:dynamodb_client) { Aws::DynamoDB::Client.new(stub_responses: true) }

  before do
    ENV['KEY_VALUE_STORE_TABLE'] = table_name
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamodb_client)
  end

  describe '.definition' do
    it 'returns a definition' do
      definition = GetBotSetting.new.definition
      expect(definition[:name]).to eq 'get_bot_setting'
    end
  end

  describe '.execute' do
    it 'gets the current model setting' do
      allow_any_instance_of(Babulus::KeyValueStore).
        to receive(:get).with(key: 'model').
        and_return('your_value')
      result = GetBotSetting.new.execute({ 'key' => 'model' })
      expect(result).to eq( 'your_value' )
    end
  end
end