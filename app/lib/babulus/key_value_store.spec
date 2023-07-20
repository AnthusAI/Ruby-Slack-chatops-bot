require 'aws-sdk-dynamodb'
require_relative 'key_value_store'

module Babulus

RSpec.describe KeyValueStore do
  let(:dynamodb_client) { instance_double(Aws::DynamoDB::Client) }
  let(:table_name) { 'babulus-key-value-store-development' }

  before do
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamodb_client)
    ENV['KEY_VALUE_STORE_TABLE'] = table_name
    @store = KeyValueStore.new
  end

  describe '#set' do
    let(:key) { 'test_key' }
    let(:value) { 'test_value' }
    let(:ttl) { Time.now.to_i + 3600 }
    
    it 'adds an item to the table' do
      expect(dynamodb_client).to receive(:put_item).with(hash_including(
        table_name: table_name,
        item: {
          'key' => key,
          'value' => value,
          'ttl' => ttl
        }
      ))
      
      @store.set(key:key, value:value, ttl: ttl)
    end
  end

  describe '#get' do
    let(:key) { 'test_key' }
    let(:value) { 'test_value' }
    
    context 'when the key exists in the table' do
      before do
        allow(dynamodb_client).to receive(:get_item).and_return(double(item: { 'value' => value }))
      end
        
      it 'returns the value' do
        expect(@store.get(key:key)).to eq(value)
      end
    end
      
    context 'when the key does not exist in the table' do
      before do
        allow(dynamodb_client).to receive(:get_item).and_return(double(item: nil))
      end
        
      context 'and a block is provided' do
        it 'returns the value computed by the block' do
          computed_value = 'computed_value'
  
          # Expect put_item to be called with the computed value
          expect(dynamodb_client).to receive(:put_item).with(hash_including(
            table_name: table_name,
            item: {
              'key' => key,
              'value' => computed_value,
              'ttl' => kind_of(Integer)
            }
          ))
  
          expect(@store.get(key:key) { computed_value }).to eq(computed_value)
        end
      end
        
      context 'and no block is provided' do
        it 'returns nil' do
          expect(@store.get(key:key)).to be_nil
        end
      end
    end
  end

end

end # module Babulus