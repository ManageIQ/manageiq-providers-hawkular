module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareServer < MiddlewareServer
    AVAIL_TYPE_ID = 'Server%20Availability~Server%20Availability'.freeze

    def feed
      CGI.unescape(super)
    end

    def immutable?
      properties['Immutable'] == 'true'
    end
  end
end
