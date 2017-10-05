module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareDomain < MiddlewareDomain
    AVAIL_TYPE_ID = 'Domain%20Availability~Domain%20Availability'.freeze

    def properties
      self.properties = super || {}
    end

    def availability
      properties['Availability']
    end

    def availability=(value)
      properties['Availability'] = value
    end
  end
end
