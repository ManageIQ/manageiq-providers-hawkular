describe ::ManageIQ::Providers::Hawkular::Inventory::Persister::AvailabilityUpdates do
  include_context 'targeted_avail_updates'

  describe '#save_servers' do
    let!(:db_server1) { ems_hawkular.middleware_servers.create(:ems_ref => 'server1', :feed => 'f1') }
    let!(:db_server2) { ems_hawkular.middleware_servers.create(:ems_ref => 'server2', :feed => 'f1', :properties => { 'Server State' => 'unknown' }) }

    it 'must update status of servers with no properties in database' do
      # Set-up
      updated_server = persister.middleware_servers.build(:ems_ref => 'server1', :properties => { 'Availability' => 'up' })
      persister.middleware_servers << updated_server

      # Try
      described_class.save_servers(ems_hawkular, persister.middleware_servers)

      # Verify
      db_server1.reload
      db_server2.reload
      expect(db_server1.properties).to eq('Availability' => 'up')
      expect(db_server2.properties).to eq('Server State' => 'unknown') # Check the other one wasn't updated
    end

    it 'must update only status related fields' do
      # Set-up
      db_server1.properties = { 'Some other data' => 'value' }
      db_server1.save!

      updated_server = persister.middleware_servers.build(
        :ems_ref    => 'server1',
        :properties => {
          'Availability'            => 'up',
          'spurious field'          => 'ok',
          'Server State'            => 'running',
          'Calculated Server State' => 'down'
        }
      )
      persister.middleware_servers << updated_server

      # Try
      described_class.save_servers(ems_hawkular, persister.middleware_servers)

      # Verify
      db_server1.reload
      expect(db_server1.properties).to eq(
        'Availability'            => 'up',
        'Server State'            => 'running',
        'Calculated Server State' => 'down',
        'Some other data'         => 'value'
      )
    end

    it 'must ignore servers not found in database' do
      # Set-up
      updated_server = persister.middleware_servers.build(:ems_ref => 'server7', :properties => { 'Server State' => 'new status' })
      persister.middleware_servers << updated_server

      # Try
      described_class.save_servers(ems_hawkular, persister.middleware_servers)

      # Verify
      db_server1.reload
      db_server2.reload
      expect(db_server1.properties).to be_blank
      expect(db_server2.properties).to eq('Server State' => 'unknown')

      ems_hawkular.middleware_servers.reload
      expect(ems_hawkular.middleware_servers.count).to eq(2)
    end
  end

  describe '#save_deployments' do
    let!(:db_deployment1) { ems_hawkular.middleware_deployments.create(:ems_ref => 'deployment1', :status => 'old status') }
    let!(:db_deployment2) { ems_hawkular.middleware_deployments.create(:ems_ref => 'deployment2', :status => 'old status') }

    it 'must update status of specified deployments' do
      # Set-up
      updated_deployment = persister.middleware_deployments.build(:ems_ref => 'deployment1', :status => 'new status')
      persister.middleware_deployments << updated_deployment

      # Try
      described_class.save_deployments(ems_hawkular, persister.middleware_deployments)

      # Verify
      db_deployment1.reload
      db_deployment2.reload
      expect(db_deployment1.status).to eq('new status')
      expect(db_deployment2.status).to eq('old status')
    end

    it 'must ignore deployments not found in database' do
      # Set-up
      updated_deployment = persister.middleware_deployments.build(:ems_ref => 'deployment7', :status => 'new status')
      persister.middleware_deployments << updated_deployment

      # Try
      described_class.save_deployments(ems_hawkular, persister.middleware_deployments)

      # Verify
      db_deployment1.reload
      db_deployment2.reload
      expect(db_deployment1.status).to eq('old status')
      expect(db_deployment2.status).to eq('old status')

      ems_hawkular.middleware_deployments.reload
      expect(ems_hawkular.middleware_deployments.count).to eq(2)
    end
  end
end
