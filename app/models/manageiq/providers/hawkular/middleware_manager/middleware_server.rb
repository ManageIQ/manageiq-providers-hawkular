module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareServer < MiddlewareServer
    AVAIL_TYPE_ID = 'Server%20Availability~Server%20Availability'.freeze

    has_many :middleware_jdr_reports, :dependent => :destroy

    def feed
      CGI.unescape(super)
    end

    def immutable?
      properties['Immutable'] == 'true'
    end

    def enqueue_jdr_report(requesting_user:)
      middleware_jdr_reports.create!(
        :requesting_user => requesting_user
      )
    end
  end
end
