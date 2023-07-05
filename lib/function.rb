require 'logger'
require 'active_support'

class Function

  @@logger = Logger.new(STDOUT)
  @@logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO

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

  def definitions
    @instances.map do |function|
      function.definition
    end.tap do |definitions|
      @@logger.debug "Function definitions:\n#{definitions.ai}"
    end
  end

  def get_metric_average_over_time(metric_name, time_window: 3600)
    @@logger.info "Getting average of metric #{metric_name} over the last #{time_window} seconds."
    namespace, metric_name = metric_name.split("::")
  
    cloudwatch = Aws::CloudWatch::Client.new
    resp = cloudwatch.get_metric_statistics({
      # The namespace of the metric, in this case, the value before "::"
      namespace: namespace,
      # The name of the metric, in this case, the value after "::"
      metric_name: metric_name,
      # The timestamp that determines the first datapoint to return.
      start_time: Time.now - time_window,
      # The timestamp that determines the last datapoint to return.
      end_time: Time.now,
      # The granularity, in seconds.
      period: 60,
      # The metric statistics.
      statistics: ["Sum"],
    })
  
    # Compute the average of the sums
    datapoints = resp.datapoints
    total = datapoints.map(&:sum).sum
    count = datapoints.size
    count.zero? ? nil : total / count
  end

end