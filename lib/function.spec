require 'rspec'
require 'active_support'
require 'awesome_print'
require_relative 'function.rb'

RSpec.describe Function do
  describe '.function_definitions' do
    it 'loads all plugin files' do
      function_definitions = Function.load.definitions

      expect(function_definitions).to be_an(Array)
      expect(function_definitions).not_to be_empty
    end
  end
end
