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
end