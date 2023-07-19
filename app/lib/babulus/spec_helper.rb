require 'simplecov'
SimpleCov.start

require 'webmock/rspec'
require 'pry'
require 'byebug'
require 'awesome_print'; ENV['HOME'] = '/var/task' if ENV['AWS_EXECUTION_ENV']

# Set the current working directory to the 'lib/' directory, which will
# be the 'app/' directory in apps built with this gem.
Dir.chdir(File.join(__dir__, '..'))
$LOAD_PATH.unshift File.expand_path('./')