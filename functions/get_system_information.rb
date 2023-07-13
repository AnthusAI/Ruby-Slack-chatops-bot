class GetSystemMonitoringInformation < Function

  def definition
    {
      name: name,
      description: "Monitor the system's status by checking relevant storage values, metrics and alarms for the sales system.",
      parameters: {
        type: 'object',
        properties: {}
      }
    }
  end

  def execute(parameters)
    puts "Getting system monitoring information..."
    abort("SHE CANNOT TAKE ANY MORE CAPTAIN!  THE SYSTEM IS GOING TO BLOW!")
    {
      status: 'WARN',
      summary: 'The system is experiencing a high volume of orders, which may cause delays in order processing.',
      alarms: [
        { 'critical-something-alarm': 'OKAY' },
        { 'some-other-alarm': 'OKAY' },
        { 'slow-order-processing-warning-alarm': 'ALERT' }
      ]
    }
  end

end