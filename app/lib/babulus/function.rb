require 'active_support'
require 'babulus'

class Function

  # Class methods, for loading the instances.

  def initialize(instances:nil, response_channel:nil)
    @response_channel = response_channel
    @key_value_store = KeyValueStore.new
  end

  def self.load(response_channel:)
    def self.load_instances(response_channel:)
      instances = []

      # Load function plugins.
      Dir.glob(File.join(__dir__,
        '../functions/**/*.rb')).each { |f| require f }

      # Instantiate each function class.

      ObjectSpace.each_object(Class) do |function_class|
        # Instantiate each function class, if it's a subclass of Function.
        if function_class.superclass.to_s.eql? 'Function'
          instances <<
            function_class.new(response_channel: response_channel)
        end
      end

      instances
    end
    @@instances ||= load_instances(response_channel: response_channel)
  end

  def self.instances
    @@instances
  end

  def self.definitions
    @@instances.map do |function|
      function.definition
    end.tap do |definitions|
      $logger.debug "Function definitions:\n#{JSON.pretty_generate(definitions)}"
    end
  end

  # Instance methods.

  def name
    ActiveSupport::Inflector.underscore self.class.to_s
  end

end