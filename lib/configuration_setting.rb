require_relative 'helper'
require_relative 'key_value_store'
require 'active_support'

module Configuration

  class Setting

    def initialize(key: nil)
      @key = key
    end

    def self.find(key:)
      case key
      when 'model'
        Model.new
      when 'temperature'
        Temperature.new
      else
        Setting.new(key: key)
      end
    end

    def computed_key
      @key || self.class.to_s.gsub(/^(.*)\:\:/,'').downcase
    end

    def get
      KeyValueStore.new.get(key: computed_key) do
        default
      end
    end

    def set(value:)
      $logger.debug "Setting #{computed_key} to #{value}"
      KeyValueStore.new.set(key: computed_key, value: value)
      {
        key: computed_key,
        value: value
      }
    end

  end

  class Model < Setting

    def default
      'gpt-3.5-turbo-0613'
    end

    def get
      super
    end

    def set(value:)
      $logger.debug "Setting model to #{value}"

      # Massage model/user input into valid model name.
      case value
      when /gpt[\s\-\_]*3.*16\s*k/i
        super(value: 'gpt-3.5-turbo-16k-0613')
      when /gpt[\s\-\_]*3/i
        super(value: 'gpt-3.5-turbo-0613')
      when /gpt[\s\-\_]*4/i
        super(value: 'gpt-4-0613')
      else
        super(value: 'gpt-3.5-turbo-0613')
      end
    end

  end

  class Temperature < Setting

    def default
      0.9
    end

    def get
      super(key: 'temperature')
    end

    def set(value:)
      case value
      when /high/i
        super(value: 1.0)
      when /medium/i
        super(value: 0.7)
      when /low/i
        super(value: 0.5)
      when /0\.?\d*/
        super(value: value.to_f)
      else
        super(value: default)
      end
    end

  end

end