class GetSystemSalesPerformanceInformation < Function

  def definition
    {
      name: name,
      description: "Monitor the system's recent revenue, transaction count, and other key performance indicators for the sales system.",
      'parameters': {
        type: 'object',
        properties: {}
      }
    }
  end

  def execute(parameters)
    puts "Getting system sales performance information..."
    {
      summary: '$1,000,000 USD in revenue from 1000 transactions, with a 10% conversion rate.',
      kpis: [
        revenue: '$1,000,000 USD',
        transactions: 1000,
        conversion_rate: '10%',
        average_order_value: '$1,000 USD',
        average_order_size: 1,
        average_order_weight: '1 kg',
        average_order_shipping_cost: '$10 USD',
        average_order_shipping_time: '1 day',
        average_order_shipping_distance: '100 km',
        top_order_shipping_method: 'ground',
        top_order_shipping_carrier: 'UPS'
      ]
    }
  end

end