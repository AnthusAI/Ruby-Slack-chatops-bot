Gem::Specification.new do |s|
  s.name          = "babulus"
  s.version       = "1.0.0"
  s.summary       = "A babbling bot that can do things."
  s.description   = "A serverless AI agent that sits between Slack and the OpenAI API that can tell you about its own CloudWatch metrics and show you metric widget images, with a plugin architecture for adding custom chat functions for doing whatever you need. With caching in DynamoDB. Notifies a Slack channel about its own alerts."
  s.authors       = ["Ryan Alyn Porter"]
  s.email         = "rap@endymion.com"
  s.require_paths = ['app/lib']
  s.homepage      = "https://github.com/endymion/Babulus"
  s.license       = "MIT"

  s.add_dependency 'awesome_print', '1.9.2'
  s.add_dependency 'activesupport', '7.0.5.1'

  s.add_dependency 'aws-sdk-cloudwatch', '1.76.0'
  s.add_dependency 'aws-sdk-core', '3.176.0'
  s.add_dependency 'aws-sdk-dynamodb', '1.88.0'
  s.add_dependency 'aws-sdk-secretsmanager', '1.78.0'
  s.add_dependency 'aws-sdk-sqs', '1.59.0'
  s.add_dependency 'aws-sdk-ssm', '1.154.0'
  s.add_dependency 'ruby-openai', '4.2.0'

  s.add_development_dependency 'pry', '~> 0.14.1'
  
end