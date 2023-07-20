require 'logger'
require 'active_support'

module Babulus

  class LoggerFactory
    def self.build(io=$stdout)
      Logger.new(io).tap do |logger|
        logger.level = !ENV['DEBUG'].blank? ? Logger::DEBUG : Logger::INFO
      end
    end
  end

end