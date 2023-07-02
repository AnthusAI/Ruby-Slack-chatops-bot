require 'logger'
require 'aws-sdk-dynamodb'

class KeyValueStore
  def initialize(dynamodb_client: nil)
    @dynamodb = dynamodb_client || Aws::DynamoDB::Client.new
    @table_name = ENV['KEY_VALUE_STORE_TABLE']
    @logger = Logger.new(STDOUT)
  end

  def set(key:, value:, ttl: (Time.now + 3600).to_i)  # TTL defaults to 1 hour
    @logger.info("Setting key: #{key} => #{value}, TTL: #{ttl}")
    begin
      @dynamodb.put_item({
        table_name: @table_name,
        item: {
          'key' => key,
          'value' => value,
          'ttl' => ttl
        }
      })
    rescue Aws::DynamoDB::Errors::ServiceError => e
      @logger.error "Unable to add item:\n#{e.message}"
    end
  end
  
  def get(key:, &block)
    @logger.info("Getting key: #{key}")
    begin
      result = @dynamodb.get_item({
        table_name: @table_name,
        key: {
          'key' => key
        }
      })

      if result.item
        @logger.info("Found key: #{key} => #{result.item['value']}")
        result.item['value']
      else
        @logger.info("Key not found: #{key}")
        if block_given?
          @logger.info("Computing value for key: #{key}")
          value = yield
          set(key:key, value:value)
          value
        end
      end
    rescue Aws::DynamoDB::Errors::ServiceError => e
      @logger.error "Unable to get item:\n#{e.message}"
      nil
    end
  end

end
