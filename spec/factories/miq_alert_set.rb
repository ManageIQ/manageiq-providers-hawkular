FactoryGirl.define do
  factory :miq_alert_set_mw, :parent => :miq_alert_set do
    mode "MiddlewareServer"
  end
end
