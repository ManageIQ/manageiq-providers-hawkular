describe ManageIQ::Providers::Hawkular::MiddlewareManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('hawkular')
  end

  it ".description" do
    expect(described_class.description).to eq('Hawkular')
  end

  describe "miq_id_prefix" do
    let(:random_id) { SecureRandom.hex(10) }
    let!(:my_region) do
      MiqRegion.my_region || FactoryGirl.create(:miq_region, :region => MiqRegion.my_region_number)
    end
    let(:random_region) do
      region = Random.rand(1..99) while !region || region == my_region.region
      MiqRegion.find_by(:region => region) || FactoryGirl.create(:miq_region, :region => region)
    end

    it "must return non-empty string" do
      rval = subject.miq_id_prefix
      expect(rval.to_s.strip).not_to be_empty
    end

    it "must prefix the provided string/identifier" do
      rval = subject.miq_id_prefix(random_id)

      expect(rval).to end_with(random_id)
      expect(rval).not_to eq(random_id)
    end

    it "must generate different prefixes for different providers" do
      ems_a = FactoryGirl.create(:ems_hawkular)
      ems_b = FactoryGirl.create(:ems_hawkular)

      expect(ems_a.miq_id_prefix).not_to eq(ems_b.miq_id_prefix)
    end

    it "must generate different prefixes for same provider on different MiQ region" do
      ems_a = FactoryGirl.create(:ems_hawkular)
      ems_b = ems_a.dup
      ems_b.id = described_class.id_in_region(ems_a.id % described_class::DEFAULT_RAILS_SEQUENCE_FACTOR, random_region.region)

      expect(ems_a.miq_id_prefix).not_to eq(ems_b.miq_id_prefix)
    end
  end

  describe 'middleware server operations:' do
    let(:ems) { FactoryGirl.create(:ems_hawkular) }
    let(:mw_server) do
      FactoryGirl.create(
        :hawkular_middleware_server,
        :ext_management_system => ems,
        :ems_ref               => '/f;f1/r;server'
      )
    end
    let(:mw_domain_server) do
      FactoryGirl.create(
        :hawkular_middleware_server,
        :ext_management_system => ems,
        :ems_ref               => '/t;hawkular/f;master.Unnamed%20Domain/r;Local~~/r;Local~%2Fhost%3Dmaster/r;Local~%2Fhost%3Dmaster%2Fserver%3Dserver-one'
      )
    end

    before(:all) do
      NotificationType.seed
    end

    def event_expectation(mw_server, op_name, status)
      expect(EmsEvent).to receive(:add_queue).with(
        'add', ems.id,
        hash_including(
          :ems_id          => ems.id,
          :event_type      => "MwServer.#{op_name}.#{status}",
          :middleware_ref  => mw_server.ems_ref,
          :middleware_type => 'MiddlewareServer'
        )
      )
    end

    def notification_expectations(mw_server, op_name, type_name)
      notification = Notification.last
      expect(notification.notification_type.name).to eq(type_name)
      expect(notification.options[:op_name]).to eq(op_name)
      expect(notification.options[:mw_server]).to eq("#{mw_server.name} (#{mw_server.feed})")
    end

    %w(shutdown suspend resume reload restart stop).each do |operation|
      it "#{operation} should create a user notificaton and timeline event on success" do
        allow_any_instance_of(::Hawkular::Operations::Client).to receive(:invoke_generic_operation) do |_, &callback|
          callback.perform(:success, nil)
        end

        op_name = operation.capitalize
        event_expectation(mw_server, op_name, "Success")

        ems.public_send("#{operation}_middleware_server", mw_server.ems_ref)
        notification_expectations(mw_server, op_name.to_sym, 'mw_op_success')
      end

      it "#{operation} should create a user notificaton and timeline event on failure" do
        allow_any_instance_of(::Hawkular::Operations::Client).to receive(:invoke_generic_operation) do |_, &callback|
          callback.perform(:failure, 'Error')
        end

        op_name = operation.capitalize
        event_expectation(mw_server, op_name, "Failed")

        ems.public_send("#{operation}_middleware_server", mw_server.ems_ref)
        notification_expectations(mw_server, op_name.to_sym, 'mw_op_failure')
      end
    end

    %w(start restart stop kill).each do |operation|
      it "domain specific '#{operation}' operation should create a user notificaton and timeline event on success" do
        allow_any_instance_of(::Hawkular::Operations::Client).to receive(:invoke_generic_operation) do |_, &callback|
          callback.perform(:success, nil)
        end

        op_name = operation.capitalize
        event_expectation(mw_domain_server, op_name, "Success")

        ems.public_send("#{operation}_middleware_domain_server",
                        mw_domain_server.ems_ref.sub(/%2Fserver%3D/, '%2Fserver-config%3D'),
                        :original_resource_path => mw_domain_server.ems_ref)
        notification_expectations(mw_domain_server, op_name.to_sym, 'mw_op_success')
      end

      it "domain specific '#{operation}' operation should create a user notificaton and timeline event on failure" do
        allow_any_instance_of(::Hawkular::Operations::Client).to receive(:invoke_generic_operation) do |_, &callback|
          callback.perform(:failure, 'Error')
        end

        op_name = operation.capitalize
        event_expectation(mw_domain_server, op_name, "Failed")

        ems.public_send("#{operation}_middleware_domain_server",
                        mw_domain_server.ems_ref.sub(/%2Fserver%3D/, '%2Fserver-config%3D'),
                        :original_resource_path => mw_domain_server.ems_ref)
        notification_expectations(mw_domain_server, op_name.to_sym, 'mw_op_failure')
      end
    end
  end
end
