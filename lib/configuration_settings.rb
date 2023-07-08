require_relative 'key_value_store'

module Configuration

  class Setting

    def self.get
      KeyValueStore.new.get(key: self.to_s.gsub(/^(.*)\:\:/,'').downcase) do
        default
      end
    end

    def self.set(value:)
      KeyValueStore.new.set(key: self.to_s.gsub(/^(.*)\:\:/,'').downcase, value: value)
    end

  end

  class Model < Setting

    def self.default
      'gpt-3.5-turbo-0613'
    end

    def self.set(value:)
      # Massage model/user input into valid model name.
      case value
      when /gpt\s*3.*16\s*k/i
        super(value: 'gpt-3.5-turbo-16k-0613')
      when /gpt\s*3/i
        super(value: 'gpt-3.5-turbo-0613')
      when /gpt\s*4/i
        super(value: 'gpt-4-0613')
      end
    end

  end

  class Temperature < Setting

    def self.default
      0.9
    end

    def self.set(value:)
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
        0.7
      end
    end

  end

end