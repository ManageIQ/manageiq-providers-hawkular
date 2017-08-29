FactoryGirl.define do
  factory :hawkular_jdr_report, :class => ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDiagnosticReport do
    requesting_user 'admin'
    status 'Queued'
    association :middleware_server, :factory => :hawkular_middleware_server
  end
end
