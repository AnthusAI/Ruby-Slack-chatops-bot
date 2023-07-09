require 'active_support'
require_relative 'helper'

class Function

  def initialize(instances:nil)
    @instances = instances
  end

  attr_reader :instances

  def self.load
    
    # Load function plugins.
    Dir.glob(File.join(__dir__,
      '../functions/**/*.rb')).each { |f| require f }

    # Instantiate each function class.
    instances = []
    ObjectSpace.each_object(Class) do |function_class|
      # Instantiate each function class, if it's a subclass of Function.
      if function_class.superclass.to_s.eql? 'Function'
        instances <<
          function_class.new
      end
    end

    self.new(instances: instances)
  end

  def name
    ActiveSupport::Inflector.underscore self.class.to_s
  end

  def definitions
    @instances.map do |function|
      function.definition
    end.tap do |definitions|
      $logger.debug "Function definitions:\n#{definitions.ai}"
    end
  end

end