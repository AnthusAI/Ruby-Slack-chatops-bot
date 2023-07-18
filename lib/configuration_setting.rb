require_relative 'helper'
require_relative 'key_value_store'
require 'active_support'

module Configuration

  class Setting

    def initialize(key: nil)
      @key = key
      @key_value_store = KeyValueStore.new
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
      @key ||
        ActiveSupport::Inflector.underscore(
          self.class.to_s.gsub(/^(.*)\:\:/,''))
    end

    def get
      $logger.debug "Getting computed key: #{computed_key}"
      @key_value_store.get(key: computed_key) do
        default
      end
    end

    def set(value:)
      $logger.debug "Setting #{computed_key} to #{value}"
      @key_value_store.set(key: computed_key, value: value)
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
      super.to_f
    end

    def set(value:)
      case value
      when /high/i
        super(value: '1.0')
      when /medium/i
        super(value: '0.7')
      when /low/i
        super(value: '0.5')
      when /0\.?\d*/
        super(value: value.to_f.to_s)
      else
        super(value: default)
      end
    end

  end

  class Boolean < Setting

    def get
      case super
      when true
        true
      when 'true'
        true
      when 'yes'
        true
      when 'enabled'
        true
      when 'active'
        true
      else
        false
      end
    end

    def set(value:)
      case value
      when /true/i
        super(value: true)
      when /yes/i
        super(value: true)
      when /enabled/i
        super(value: true)
      when /active/i
        super(value: true)
      else
        super(value: false)
      end
    end

  end

  class StatusEmojis < Boolean

    def default
      true
    end

  end

end