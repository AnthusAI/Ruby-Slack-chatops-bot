require_relative 'logger_factory.rb'
$logger = LoggerFactory.build($stdout)

require 'awesome_print'; ENV['HOME'] = '/var/task' if ENV['AWS_EXECUTION_ENV']

require_relative 'function.rb'
require_relative 'cloudwatch_metrics'
require_relative 'configuration_setting'
