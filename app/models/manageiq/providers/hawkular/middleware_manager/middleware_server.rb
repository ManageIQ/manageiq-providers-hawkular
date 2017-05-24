module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareServer < MiddlewareServer
    def feed
      CGI.unescape(super)
    end

    def immutable?
      properties['Immutable'] == 'true'
    end
  end
end
