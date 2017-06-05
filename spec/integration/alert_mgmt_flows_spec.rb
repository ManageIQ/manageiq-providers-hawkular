require_relative '../models/manageiq/providers/hawkular/middleware_manager/hawkular_helper'

describe "Alert mgmt flow:" do
  let(:alert) { FactoryGirl.create(:miq_alert_mw_heap_used, :id => 201) }

  subject!(:ems) do
    ems = ems_hawkular_fixture
    ems.guid = "def"
    ems.save!
    ems
  end

  before do
    MiqRegion.seed
    MiqRegion.my_region.guid = "abc"
    MiqRegion.my_region.save!
    @hwclient = nil
  end

  around do |ex|
    vcr_opts = ex.metadata[:vcr]

    cassette_name = vcr_opts.delete(:cassette_name)
    cassette_name = "integration/alert_mgmt_flows/#{cassette_name}"

    VCR.use_cassette(cassette_name, vcr_opts, &ex)
  end

  def ems_class
    ManageIQ::Providers::Hawkular::MiddlewareManager
  end

  def alert_manager_class
    ManageIQ::Providers::Hawkular::MiddlewareManager::AlertManager
  end

  def hawkular_client
    @hclient ||= Hawkular::Client.new(
      :credentials => {
        :username => test_userid,
        :password => test_password
      },
      :options     => { :tenant => 'hawkular' },
      :entrypoint  => URI::HTTP.build(:host => test_hostname, :port => test_port)
    )
  end

  def alerts_client
    hawkular_client.alerts
  end

  describe "alerts" do
    it "CRUD flow is propagated to Hawkular", :vcr => { :cassette_name => 'alerts_crud_flow' } do
      # STAGE 1
      # Notify to EMS an alert was created
      ems_class.update_alert(:operation => :new, :alert => alert)

      # Verify a trigger is in Hawkular
      hawkular_alert_id = alert_manager_class.build_hawkular_trigger_id(:ems => ems, :alert => alert)
      trigger = alerts_client.list_triggers(hawkular_alert_id)
      expect(trigger.count).to eq(1)

      # STAGE 2
      # Update alert condition and notify to EMS
      alert.expression[:options][:value_mw_greater_than] = 50
      alert.save
      ems_class.update_alert(:operation => :update, :alert => alert)

      # Verify trigger condition was updated in Hawkular
      trigger = alerts_client.get_single_trigger(hawkular_alert_id, true)
      expect(trigger.conditions.count).to eq(2)

      updated_condition = trigger.conditions.find { |c| c.operator == 'GT' }
      expect(updated_condition.data2_multiplier).to eq(0.5)

      # STAGE 3
      # Delete alert and notify to EMS
      alert.destroy
      ems_class.update_alert(:operation => :delete, :alert => alert)

      # Verify trigger has been deleted in Hawkular
      trigger = alerts_client.list_triggers(hawkular_alert_id)
      expect(trigger.count).to be_zero
    end

    it "should fallback to old alerts id format if an alert with the new id does not exist in Hawkular",
       :vcr => { :cassette_name => 'fallback_to_old_ids_format' } do
      # Temporarily mock construction of id
      allow(alert_manager_class).to receive(:build_hawkular_trigger_id).and_return("MiQ-#{alert.id}")

      # Create alert in Hawkular with old id format
      ems_class.update_alert(:operation => :new, :alert => alert)

      trigger = alerts_client.list_triggers("MiQ-#{alert.id}")
      expect(trigger.count).to eq(1)

      # Remove mock
      allow(alert_manager_class).to receive(:build_hawkular_trigger_id).and_call_original
      expect(alert_manager_class.build_hawkular_trigger_id(:ems => ems, :alert => { :id => 1 })).to include('ems') # just to check mock is removed

      # Delete alert and notify to EMS
      alert.destroy
      ems_class.update_alert(:operation => :delete, :alert => alert)

      # Verify trigger has been deleted in Hawkular
      trigger = alerts_client.list_triggers("MiQ-#{alert.id}")
      expect(trigger.count).to be_zero
    end
  end

  describe "alert profiles" do
    # This context assumes that there is a wildfly server
    # in domain mode (with the shipped sample domain configs)
    # connected to hawkular services. This means that hawkular
    # should have registered the relevant inventory entities.

    let(:profile) { FactoryGirl.create(:miq_alert_set_mw, :id => 202) }
    let(:server_one) do
      s1 = ManageIQ::Providers::Hawkular::MiddlewareManager::
        MiddlewareServer.find_by(:name => 'server-one')
      s1.update_column(:id, 400)
      s1.reload
    end

    before do
      VCR.use_cassette('integration/alert_mgmt_flows/profiles_hawkular_setup') do # , :record => :all) do
        # Update MiQ inventory
        EmsRefresh.refresh(ems)
        ems.reload

        # Place group trigger in Hawkular
        ems_class.update_alert(:operation => :new, :alert => alert)
        alert.reload
      end
    end

    after do
      VCR.use_cassette('integration/alert_mgmt_flows/profiles_hawkular_cleanup') do # , :record => :all) do
        # Cleanup group trigger in Hawkular
        ems_class.update_alert(:operation => :delete, :alert => alert)
      end
    end

    it "without assigned servers shouldn't create members in Hawkular when adding alerts",
       :vcr => { :cassette_name => 'add_alerts_to_profile_with_no_servers' } do
      # Setup
      profile.add_member(alert)

      ems_class.update_alert_profile(
        :operation       => :update_alerts,
        :profile_id      => profile.id,
        :old_alerts      => [],
        :new_alerts      => [alert.id],
        :old_assignments => [],
        :new_assignments => nil
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to be_zero
    end

    it "without alerts shouldn't create members in Hawkular when adding servers",
       :vcr => { :cassette_name => 'add_servers_to_profile_with_no_alerts' } do
      # Setup
      profile.assign_to_objects([server_one])

      ems_class.update_alert_profile(
        :operation       => :update_assignments,
        :profile_id      => profile.id,
        :old_alerts      => [],
        :new_alerts      => [],
        :old_assignments => [],
        :new_assignments => {"objects" => [server_one.id], "assign_to" => server_one.class}
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to be_zero
    end

    it "with alerts should update members in Hawkular when assigning and unassigning a server",
       :vcr => { :cassette_name => 'assign_unassign_server_to_profile_with_alerts' } do
      # Setup
      profile.add_member(alert)

      # Add the server
      profile.assign_to_objects([server_one])

      ems_class.update_alert_profile(
        :operation       => :update_assignments,
        :profile_id      => profile.id,
        :old_alerts      => [alert.id],
        :new_alerts      => [],
        :old_assignments => [],
        :new_assignments => {"objects" => [server_one.id], "assign_to" => server_one.class}
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to eq(1)

      # Remove server
      profile.remove_all_assigned_tos

      ems_class.update_alert_profile(
        :operation       => :update_assignments,
        :profile_id      => profile.id,
        :old_alerts      => [alert.id],
        :new_alerts      => [],
        :old_assignments => [server_one],
        :new_assignments => nil
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to be_zero
    end

    it "with servers should update members in Hawkular when assigning and unassigning an alert",
       :vcr => { :cassette_name => 'assign_unassign_alert_to_profile_with_servers' } do
      # Setup
      profile.assign_to_objects([server_one])

      # Add the alert
      profile.add_member(alert)
      ems_class.update_alert_profile(
        :operation       => :update_alerts,
        :profile_id      => profile.id,
        :old_alerts      => [],
        :new_alerts      => [alert.id],
        :old_assignments => [server_one],
        :new_assignments => nil
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to eq(1)

      # Remove the alert
      profile.remove_member(alert)

      ems_class.update_alert_profile(
        :operation       => :update_alerts,
        :profile_id      => profile.id,
        :old_alerts      => [alert.id],
        :new_alerts      => [],
        :old_assignments => [server_one],
        :new_assignments => nil
      )

      # Verify
      triggers = alerts_client.list_triggers
      expect(triggers.select { |t| t.type == 'MEMBER' }.count).to be_zero
    end
  end
end
