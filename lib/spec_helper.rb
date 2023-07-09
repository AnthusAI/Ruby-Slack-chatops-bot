require 'simplecov'
SimpleCov.start

require 'webmock/rspec'
require 'pry'
require 'byebug'
require 'awesome_print'; ENV['HOME'] = '/var/task' if ENV['AWS_EXECUTION_ENV']