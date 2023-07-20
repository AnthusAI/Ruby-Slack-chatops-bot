require_relative 'spec_helper.rb'
require_relative 'logger_factory.rb'

module Babulus

describe LoggerFactory do

  before do
    @output = StringIO.new
    @logger = LoggerFactory.build(@output)
  end

  it "logs info to STDOUT" do
    @logger.info("Hello, world!")
    expect(@output.string).to include("Hello, world!")
  end

  it "does not log debugging stuff to STDOUT" do
    @logger.info("Hello, world!")
    @logger.debug("details, details, yadda, yadda, yadda")
    expect(@output.string).not_to include("details")
  end

  context "when the environment variable is set" do
    before do
      @previous_debug_value = ENV['DEBUG']
      ENV['DEBUG'] = 'true'

      @logger = LoggerFactory.build(@output)
    end
    
    it "logs debugging stuff to STDOUT" do
      @logger.info("Hello, world!")
      @logger.debug("details, details, yadda, yadda, yadda")
      expect(@output.string).to include("details")
    end

    after do
      ENV['DEBUG'] = @previous_debug_value
    end
  end

end

end # module Babulus