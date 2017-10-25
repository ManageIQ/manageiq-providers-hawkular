describe ManageIQ::Providers::Hawkular::MiddlewareManager::AlertManager do
  let(:client) { double('Hawkular::Alerts') }
  let(:stubbed_ems) do
    ems = instance_double('::ManageIQ::Providers::Hawkular::MiddlewareManager',
                          :alerts_client => client,
                          :id            => 5)
    allow(ems).to receive(:miq_id_prefix) { |id| id }
    ems
  end
  let(:subject) { described_class.new(stubbed_ems) }

  it '#convert_operator' do
    expect(subject.send(:convert_operator, "<")).to eq(:LT)
    expect(subject.send(:convert_operator, "<=")).to eq(:LTE)
    expect(subject.send(:convert_operator, ">=")).to eq(:GTE)
    expect(subject.send(:convert_operator, "=")).to eq(:LTE)
    expect(subject.send(:convert_operator, ">")).to eq(:GT)
    expect(subject.send(:convert_operator, "wrong operator")).to eq(nil)
  end

  it '#generate_mw_threshold_condition' do
    c = subject.send(:generate_mw_threshold_condition, "1", :LT, 3)
    expect(c).to be_a_kind_of(Hawkular::Alerts::Trigger::Condition)
    expect(c.data_id).to eq("1")
    expect(c.trigger_mode).to eq(:FIRING)
    expect(c.type).to eq(:THRESHOLD)
    expect(c.operator).to eq(:LT)
    expect(c.threshold).to eq(3)
  end

  context "Test conditions" do
    let(:miq_alert_condition) do
      {
        :id          => 1,
        :enabled     => true,
        :description => "Alert sample description",
        :conditions  => {
          :eval_method => '',
          :mode        => 'internal',
          :options     => {}
        },
        :based_on    => "MiddlewareServer"
      }
    end

    it '#convert_to_group_conditions MW GC' do
      miq_alert_condition[:conditions][:eval_method] = "mw_accumulated_gc_duration"
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      expect(subject).to receive(:generate_mw_gc_condition).with(
        'mw_accumulated_gc_duration',
        :mw_operator                => "<",
        :value_mw_garbage_collector => 100
      )
      subject.send(:convert_to_group_conditions, miq_alert_condition)
    end

    it '#convert_to_group_conditions MW GC' do
      miq_alert_condition[:conditions][:eval_method] = "mw_accumulated_gc_duration"
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      expect(subject).to receive(:generate_mw_gc_condition).with(
        'mw_accumulated_gc_duration',
        :mw_operator                => "<",
        :value_mw_garbage_collector => 100
      )
      subject.send(:convert_to_group_conditions, miq_alert_condition)
    end

    it '#convert_to_group_conditions MW Heap' do
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      %w(mw_heap_used mw_non_heap_used).each do |condition|
        miq_alert_condition[:conditions][:eval_method] = condition
        expect(subject).to receive(:generate_mw_jvm_conditions).with(
          condition,
          :mw_operator                => "<",
          :value_mw_garbage_collector => 100
        )
        subject.send(:convert_to_group_conditions, miq_alert_condition)
      end
    end

    it '#convert_to_group_conditions Sessions' do
      MW_WEB_SESSIONS = %w(
        mw_aggregated_active_web_sessions
        mw_aggregated_expired_web_sessions
        mw_aggregated_rejected_web_sessions
      ).freeze
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      MW_WEB_SESSIONS.each do |condition|
        miq_alert_condition[:conditions][:eval_method] = condition
        definition = MiddlewareServer.live_metrics_config['middleware_server']['supported_metrics_by_column'][condition]
        expect(definition).not_to be_nil
        expect(subject).to receive(:generate_mw_generic_threshold_conditions).with(
          {
            :mw_operator                => "<",
            :value_mw_garbage_collector => 100
          },
          definition
        )
        subject.send(:convert_to_group_conditions, miq_alert_condition)
      end
    end

    it '#convert_to_group_conditions DataSource' do
      MW_DATASOURCE = %w(
        mw_ds_available_count
        mw_ds_in_use_count
        mw_ds_timed_out
        mw_ds_average_get_time
        mw_ds_average_creation_time
        mw_ds_max_wait_time
      ).freeze
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      MW_DATASOURCE.each do |condition|
        miq_alert_condition[:conditions][:eval_method] = condition
        definition = MiddlewareDatasource.live_metrics_config['middleware_datasource']['supported_metrics_by_column'][condition]
        expect(definition).not_to be_nil
        expect(subject).to receive(:generate_mw_generic_threshold_conditions).with(
          {
            :mw_operator                => "<",
            :value_mw_garbage_collector => 100
          },
          definition
        )
        subject.send(:convert_to_group_conditions, miq_alert_condition)
      end
    end

    it '#convert_to_group_conditions Messaging' do
      MW_MESSAGING = %w(
        mw_ms_topic_delivering_count
        mw_ms_topic_durable_message_count
        mw_ms_topic_non_durable_message_count
        mw_ms_topic_message_count
        mw_ms_topic_message_added
        mw_ms_topic_durable_subscription_count
        mw_ms_topic_non_durable_subscription_count
        mw_ms_topic_subscription_count
      ).freeze
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      MW_MESSAGING.each do |condition|
        miq_alert_condition[:conditions][:eval_method] = condition
        definition = MiddlewareMessaging.live_metrics_config['middleware_messaging_jms_topic']['supported_metrics_by_column'][condition]
        expect(definition).not_to be_nil
        expect(subject).to receive(:generate_mw_generic_threshold_conditions).with(
          {
            :mw_operator                => "<",
            :value_mw_garbage_collector => 100
          },
          definition
        )
        subject.send(:convert_to_group_conditions, miq_alert_condition)
      end
    end

    it '#convert_to_group_conditions Transactions' do
      MW_TRANSACTIONS = %w(
        mw_tx_committed
        mw_tx_timeout
        mw_tx_heuristics
        mw_tx_application_rollbacks
        mw_tx_resource_rollbacks
        mw_tx_aborted
      ).freeze
      miq_alert_condition[:conditions][:options][:mw_operator] = "<"
      miq_alert_condition[:conditions][:options][:value_mw_garbage_collector] = 100
      MW_TRANSACTIONS.each do |condition|
        miq_alert_condition[:conditions][:eval_method] = condition
        definition = MiddlewareServer.live_metrics_config['middleware_server']['supported_metrics_by_column'][condition]
        expect(definition).not_to be_nil
        expect(subject).to receive(:generate_mw_generic_threshold_conditions).with(
          {
            :mw_operator                => "<",
            :value_mw_garbage_collector => 100
          },
          definition
        )
        subject.send(:convert_to_group_conditions, miq_alert_condition)
      end
    end
  end
end
