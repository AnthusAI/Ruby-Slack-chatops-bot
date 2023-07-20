require_relative '../spec_helper.rb'
require_relative 'setting.rb'

ENV['ENVIRONMENT'] = 'development'
ENV['AWS_RESOURCE_NAME'] = 'Slack Bot'

WebMock.allow_net_connect!

module Babulus

RSpec.describe Babulus::Configuration::Setting do

  let(:table_name) { 'Babulus-key-value-store-development' }
  
  before do
    ENV['KEY_VALUE_STORE_TABLE'] = table_name
  end

  describe '.set' do

    it 'sets a configuration setting value' do
      allow_any_instance_of(KeyValueStore).
        to receive(:set).with(key: 'foo', :value=>"bar").
        and_return(true)

      new_setting = Configuration::Setting.
        find(key: 'foo').set(value: 'bar')

      expect(new_setting).to eq({
        key: 'foo',
        value: 'bar'
      })
    end

    it 'sets the computed model configuration setting value' do
      input_model_name = 'GPT 3'
      output_model_name = 'gpt-3.5-turbo-0613'

      allow_any_instance_of(KeyValueStore).
        to receive(:set).with(key: 'model', value: output_model_name).
        and_return(true)

      new_setting = Configuration::Setting.
        # This posts "gpt-3.5", expecting to get the computed value back.
        find(key: 'model').set(value: input_model_name)
    
      expect(new_setting).to eq({
        key: 'model',
        value: output_model_name
      })
    end

    it 'sets the computed model temperature setting value' do
      input_temperature = 'low'
      output_temperature = '0.5'

      allow_any_instance_of(KeyValueStore).
        to receive(:set).with(key: 'temperature', value: output_temperature).
        and_return(true)
      
      new_setting = Configuration::Setting.
        find(key: 'temperature').set(value: input_temperature)
    
      expect(new_setting).to eq({
        key: 'temperature',
        value: output_temperature
      })
    end

  end

end

end