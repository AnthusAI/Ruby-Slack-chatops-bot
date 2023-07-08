require_relative '../lib/spec_helper.rb'
require_relative '../lib/function.rb'
require_relative 'get_bot_information.rb'

ENV['ENVIRONMENT'] = 'development'
ENV['AWS_RESOURCE_NAME'] = 'Slack Bot'

WebMock.allow_net_connect!

RSpec.describe GetBotInformation do

  let(:table_name) { 'TestTable' }
  
  before do
    ENV['KEY_VALUE_STORE_TABLE'] = table_name
  end

  describe '.definition' do
    it 'returns a definition' do
      definition = GetBotInformation.new.definition

      puts "Definition:\n#{definition.ai}"

      expect(definition[:name]).to eq 'get_bot_information'
    end
  end

  describe '.execute' do

    it 'gets metric statistics' do
      result = GetBotInformation.new.execute({})

      puts "Result:\n#{result.ai}"
    end

    it 'gets the current model setting' do
      result = GetBotInformation.new.execute({'key' => 'model'})
    
      puts "Result:\n#{result.ai}"
    end
    
  end
end
