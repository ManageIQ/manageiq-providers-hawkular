FactoryGirl.define do
  factory :miq_alert_middleware, :parent => :miq_alert do
    db "MiddlewareServer"
  end
end
