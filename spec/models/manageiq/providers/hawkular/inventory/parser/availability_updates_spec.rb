describe ManageIQ::Providers::Hawkular::Inventory::Parser::AvailabilityUpdates do
  describe "#parse" do
    include_context 'targeted_avail_updates'

    it "must create an item in persister with new status data for each server reported by collector" do
      # Setup
      avail_data = {
        'Availability'            => 'up',
        'Server State'            => 'running',
        'Calculated Server State' => 'running'
      }

      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_servers,
        :manager_ref => { :ems_ref => 'abc' },
        :options     => avail_data
      )

      # Try
      parser.parse

      # Verify
      item = persister.middleware_servers.find('abc')
      expect(item.manager_uuid).to eq('abc')
      expect(item.properties).to eq(avail_data)

      expect(persister.middleware_deployments.size).to be_zero
    end

    it "must create an item in persister with new status data for each deployment reported by collector" do
      # Setup
      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_deployments,
        :manager_ref => { :ems_ref => 'def' },
        :options     => { :status => 'ready' }
      )

      # Try
      parser.parse

      # Verify
      item = persister.middleware_deployments.find('def')
      expect(item).to be
      expect(item.manager_uuid).to eq('def')
      expect(item.status).to eq('ready')

      expect(persister.middleware_servers.size).to be_zero
    end

    it "must create an item in persister with new status data for each domain reported by collector" do
      # Setup
      avail_data = {
        'Host State'    => 'up',
        'Server State'  => 'running',
        'Suspend State' => 'running'
      }

      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_domains,
        :manager_ref => { :ems_ref => 'dom' },
        :options     => avail_data
      )

      # Try
      parser.parse

      # Verify
      item = persister.middleware_domains.find('dom')
      expect(item.manager_uuid).to eq('dom')
      expect(item.properties).to eq(avail_data)

      expect(persister.middleware_domains.size).to be_zero
    end

    it "must create one persister item if two servers in collector have same ems_ref" do
      # Setup
      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_servers,
        :manager_ref => { :ems_ref => 'abc' },
        :options     => { 'Server State' => 'ok' }
      )
      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_servers,
        :manager_ref => { :ems_ref => 'abc' },
        :options     => { 'Server State' => 'not ok' }
      )

      # Try
      parser.parse

      # Verify
      expect(persister.middleware_servers.size).to eq(1)
    end

    it "must create one persister item if two deployments in collector have same ems_ref" do
      # Setup
      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_deployments,
        :manager_ref => { :ems_ref => 'def' },
        :options     => { :status => 'ready' }
      )
      target << ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_deployments,
        :manager_ref => { :ems_ref => 'def' },
        :options     => { :status => 'not ready' }
      )

      # Try
      parser.parse

      # Verify
      expect(persister.middleware_deployments.size).to eq(1)
    end
  end
end
