module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareDomain < MiddlewareDomain
    AVAIL_TYPE_ID = 'Domain%20Availability~Domain%20Availability'.freeze

    def availability
      properties['Availability']
    end
  end
end
