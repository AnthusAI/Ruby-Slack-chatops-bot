require 'babulus/logger_factory.rb'
$logger = Babulus::LoggerFactory.build($stdout)

require 'awesome_print'; ENV['HOME'] = '/var/task' if ENV['AWS_EXECUTION_ENV']

require 'babulus/logger_factory'
require 'babulus/key_value_store'
require 'babulus/function'
require 'babulus/cloudwatch_metrics'
require 'babulus/configuration/setting'
require 'babulus/openai_chat_bot'
require 'babulus/openai_token_estimator'
require 'babulus/slack_channel'
require 'babulus/response_channel'
require 'babulus/slack_conversation_history'
require 'babulus/slack_events_api'