require 'rspec'
require 'active_support'
require 'awesome_print'; ENV['HOME'] = '/var/task' if ENV['AWS_EXECUTION_ENV']
require_relative 'function.rb'

module Babulus

RSpec.describe Function do
  let(:response_channel) { instance_double(ResponseChannel) }

  before do
    Function.load(response_channel: response_channel)
  end

  describe '.function_definitions' do
    it 'loads all plugin files' do
      expect(Function.definitions).to be_an(Array)
      expect(Function.definitions).not_to be_empty
    end
  end
end

end