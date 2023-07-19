require 'aws-sdk-dynamodb'
require 'babulus'

class KeyValueStore
  def initialize
    @table_name = ENV['KEY_VALUE_STORE_TABLE']
    raise 'No table name set' unless @table_name

    @dynamodb =
      Aws::DynamoDB::Client.new(:region => ENV['AWS_REGION'] || 'us-east-1')
  end

  def set(key:, value:, ttl: (Time.now + 3600).to_i)  # TTL defaults to 1 hour
    $logger.debug("Setting key: #{key} => #{value}, TTL: #{ttl}")
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
      $logger.error "Unable to add item:\n#{e.message}"
      raise e
    end
  end
  
  def get(key:, &block)
    $logger.debug("Getting key: #{key}")
    begin
      result = @dynamodb.get_item({
        table_name: @table_name,
        key: {
          'key' => key
        }
      })

      if result.item
        $logger.debug("Found key: #{key} => #{result.item['value']}")
        result.item['value']
      else
        $logger.debug("Key not found: #{key}")
        if block_given?
          $logger.debug("Computing value for key: #{key}")
          value = yield
          set(key:key, value:value)
          value
        end
      end
    rescue Aws::DynamoDB::Errors::ServiceError => e
      $logger.error "Unable to get item:\n#{e.message}"
      raise e
    end.tap do |value|
      $logger.debug("Returning value: #{value}")
    end
  end

end
