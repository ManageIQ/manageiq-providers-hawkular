FactoryGirl.define do
  factory :miq_alert_middleware, :parent => :miq_alert do
    db "MiddlewareServer"
  end

  factory :miq_alert_mw_heap_used, :parent => :miq_alert_middleware do
    description "Jvm Heap Used Alert"
    options(
      :notifications => {
        :delay_next_evaluation => 60,
        :evm_event             => { }
      }
    )
    expression(
      :eval_method => 'mw_heap_used',
      :mode        => 'internal',
      :options     => {
        :value_mw_greater_than => 90,
        :value_mw_less_than    => 10
      }
    )
    responds_to_events 'hawkular_alert'
  end
end
