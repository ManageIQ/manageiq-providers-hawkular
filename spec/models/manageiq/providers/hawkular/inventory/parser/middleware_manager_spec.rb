require_relative '../../middleware_manager/hawkular_helper'

describe ManageIQ::Providers::Hawkular::Inventory::Parser::MiddlewareManager do
  def inventory_object_data(inventory_object)
    inventory_object
      .data
      .slice(*inventory_object.inventory_collection.inventory_object_attributes)
  end

  let(:ems_hawkular) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => 'localhost',
                       :port            => 8080,
                       :authentications => [auth],
                       :zone            => zone)
  end
  let(:persister) { ::ManageIQ::Providers::Hawkular::Inventory::Persister::MiddlewareManager.new(ems_hawkular, ems_hawkular) }
  let(:collector_double) { instance_double('ManageIQ::Providers::Hawkular::Inventory::Collector::MiddlewareManager') }
  let(:persister_double) { instance_double('ManageIQ::Providers::Hawkular::Inventory::Persister::MiddlewareManager') }
  let(:parser) do
    parser = described_class.new
    parser.collector = collector_double
    parser.persister = persister_double
    parser
  end
  let(:stubbed_metric_data) { OpenStruct.new(:id => 'm1', :data => [{'timestamp' => 1, 'value' => 'arbitrary value'}]) }
  let(:server) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :name                  => 'Local',
                       :feed                  => the_feed_id,
                       :ems_ref               => '/t;Hawkular'\
                                                 "/f;#{the_feed_id}/r;Local~~",
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular,
                       :properties            => { 'Server Status' => 'Inventory Status' })
  end

  describe 'parse_datasource' do
    it 'handles simple data' do
      # parse_datasource(server, datasource, config)
      datasource = double(:name => 'ruby-sample-build',
                          :id   => 'Local~/subsystem=datasources/data-source=ExampleDS',
                          :path => '/t;Hawkular'\
                            "/f;#{the_feed_id}/r;Local~~"\
                            '/r;Local~%2Fsubsystem%3Ddatasources%2Fdata-source%3DExampleDS')
      config = {
        'value' => {
          'Driver Name'    => 'h2',
          'JNDI Name'      => 'java:jboss/datasources/ExampleDS',
          'Connection URL' => 'jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE',
          'Enabled'        => 'true'
        }
      }
      parsed_datasource = {
        :name       => 'ruby-sample-build',
        :nativeid   => 'Local~/subsystem=datasources/data-source=ExampleDS',
        :ems_ref    => '/t;Hawkular'\
                            "/f;#{the_feed_id}/r;Local~~"\
                            '/r;Local~%2Fsubsystem%3Ddatasources%2Fdata-source%3DExampleDS',
        :properties => {
          'Driver Name'    => 'h2',
          'JNDI Name'      => 'java:jboss/datasources/ExampleDS',
          'Connection URL' => 'jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE',
          'Enabled'        => 'true'
        }
      }
      inventory_obj = persister.middleware_datasources.build(:ems_ref => datasource.path)
      parser.parse_datasource(datasource, inventory_obj, config)
      expect(inventory_object_data(inventory_obj)).to eq(parsed_datasource)
    end
  end

  describe 'parse_domain' do
    it 'handles simple data' do
      properties = {
        'Running Mode'         => 'NORMAL',
        'Version'              => '9.0.2.Final',
        'Product Name'         => 'WildFly Full',
        'Host State'           => 'running',
        'Is Domain Controller' => 'true',
        'Name'                 => 'master',
      }
      feed = 'master.Unnamed%20Domain'
      id = 'Local~/host=master'
      path = '/t;hawkular/f;master.Unnamed%20Domain/r;Local~~/r;Local~%2Fhost%3Dmaster'
      type_path = '/t;hawkular/f;master.Unnamed%20Domain/rt;Domain%20Host'
      domain = OpenStruct.new(:feed       => feed,
                              :id         => id,
                              :path       => path,
                              :properties => properties,
                              :type_path  => type_path)
      parsed_domain = {
        :name       => 'Unnamed Domain',
        :feed       => feed,
        :type_path  => type_path,
        :nativeid   => id,
        :ems_ref    => path,
        :properties => properties,
      }
      inventory_obj = persister.middleware_domains.build(:ems_ref => path)
      parser.parse_middleware_domain('master.Unnamed Domain', domain, inventory_obj)
      expect(inventory_object_data(inventory_obj)).to eq(parsed_domain)
    end
  end

  describe 'fetch_availabilities_for' do
    let(:stubbed_resource) { OpenStruct.new(:manager_uuid => '/t;hawkular/f;f1/r;stubbed_resource') }
    let(:stubbed_metric_definition) { OpenStruct.new(:path => '/t;hawkular/f;f1/r;stubbed_resource/m;m1', :hawkular_metric_id => 'm1') }

    before do
      allow(collector_double).to receive(:metrics_for_metric_type).and_return([])
      allow(collector_double).to receive(:metrics_for_metric_type)
        .with('f1', 'metric_type')
        .and_return([stubbed_metric_definition])
      allow(collector_double).to receive(:raw_availability_data)
        .with(%w(m1), hash_including(:order => 'DESC'))
        .and_return([stubbed_metric_data])
    end

    def call_subject(feeds = %w(f1), resources = [stubbed_resource])
      matched_metrics = {}
      parser.fetch_availabilities_for(feeds, resources, 'metric_type') do |resource, metric|
        matched_metrics[resource] = metric
      end

      matched_metrics
    end

    it 'must query collector for metrics for every feed' do
      expect(collector_double).to receive(:metrics_for_metric_type).with('f1', 'metric_type')
      expect(collector_double).to receive(:metrics_for_metric_type).with('f2', 'metric_type')

      parser.fetch_availabilities_for(%w(f2 f1), [], 'metric_type')
    end

    it 'must call block with missing metrics to allow caller to set defaults' do
      stubbed_resource.manager_uuid += 'idsuffix'

      matched_metrics = call_subject
      expect(matched_metrics).to eq(stubbed_resource => nil)
    end

    it 'must call block with matching resource and metric to allow caller to process the metric' do
      matched_metrics = call_subject
      expect(matched_metrics).to eq(stubbed_resource => stubbed_metric_data)
    end

    it 'must call block handling a metric shared by more than one resource' do
      stubbed_resource2 = OpenStruct.new(:manager_uuid => '/t;hawkular/f;f1/r;stubbed_resource2')
      stubbed_metric_definition2 = OpenStruct.new(:path => '/t;hawkular/f;f1/r;stubbed_resource2/m;m1', :hawkular_metric_id => 'm1')

      expect(collector_double).to receive(:metrics_for_metric_type)
        .with('f1', 'metric_type')
        .and_return([stubbed_metric_definition, stubbed_metric_definition2])

      matched_metrics = call_subject(%w(f1), [stubbed_resource, stubbed_resource2])
      expect(matched_metrics).to eq(stubbed_resource => stubbed_metric_data, stubbed_resource2 => stubbed_metric_data)
    end

    it 'must call block handling resources in more than one feed' do
      stubbed_resource2 = OpenStruct.new(:manager_uuid => '/t;hawkular/f;another_feed/r;stubbed_resource')
      stubbed_metric_definition2 = OpenStruct.new(:path => '/t;hawkular/f;another_feed/r;stubbed_resource/m;m2', :hawkular_metric_id => 'm2')
      stubbed_metric_data2 = OpenStruct.new(:id => 'm2', :data => [{'timestamp' => 1, 'value' => 'other value'}])

      expect(collector_double).to receive(:metrics_for_metric_type)
        .with('another_feed', 'metric_type')
        .and_return([stubbed_metric_definition2])
      expect(collector_double).to receive(:raw_availability_data)
        .with(%w(m1 m2), hash_including(:order => 'DESC'))
        .and_return([stubbed_metric_data, stubbed_metric_data2])

      matched_metrics = call_subject(%w(another_feed f1), [stubbed_resource, stubbed_resource2])
      expect(matched_metrics).to eq(stubbed_resource => stubbed_metric_data, stubbed_resource2 => stubbed_metric_data2)
    end
  end

  describe 'fetch_deployment_availabilities' do
    let(:stubbed_deployment) { OpenStruct.new(:manager_uuid => '/t;hawkular/f;f1/r;s1/r;d1') }

    before do
      allow(persister_double).to receive(:middleware_deployments).and_return([stubbed_deployment])
      allow(parser).to receive(:fetch_availabilities_for)
        .and_yield(stubbed_deployment, stubbed_metric_data)
    end

    it 'uses fetch_availabilities_for to fetch deployment availabilities' do
      parser.fetch_deployment_availabilities(%w(f1))
      expect(parser).to have_received(:fetch_availabilities_for)
        .with(%w(f1), [stubbed_deployment], 'Deployment%20Status~Deployment%20Status')
    end

    it 'assigns enabled status to a deployment with "up" metric' do
      stubbed_metric_data.data.first['value'] = 'up'

      parser.fetch_deployment_availabilities(%w(f1))
      expect(stubbed_deployment.status).to eq('Enabled')
    end

    it 'assigns disabled status to a deployment with "down" metric' do
      stubbed_metric_data.data.first['value'] = 'down'

      parser.fetch_deployment_availabilities(%w(f1))
      expect(stubbed_deployment.status).to eq('Disabled')
    end

    it 'assigns unknown status to a deployment whose metric is something else than "up" or "down"' do
      parser.fetch_deployment_availabilities(%w(f1))
      expect(stubbed_deployment.status).to eq('Unknown')
    end

    it 'assigns unknown status to a deployment with a missing metric' do
      allow(parser).to receive(:fetch_availabilities_for)
        .and_yield(stubbed_deployment, nil)

      parser.fetch_deployment_availabilities(%w(f1))
      expect(stubbed_deployment.status).to eq('Unknown')
    end
  end

  describe 'fetch_server_availabilities' do
    before do
      allow(persister_double).to receive(:middleware_servers).and_return([server])
      allow(parser).to receive(:fetch_availabilities_for)
        .and_yield(server, stubbed_metric_data)
    end

    it 'uses fetch_availabilities_for to resolve server availabilities' do
      parser.fetch_server_availabilities(%w(f1))
      expect(parser).to have_received(:fetch_availabilities_for)
        .with(%w(f1), [server], 'Server%20Availability~Server%20Availability')
    end

    it 'assigns status reported by inventory to a server with "up" metric' do
      stubbed_metric_data.data.first['value'] = 'up'

      parser.fetch_server_availabilities(%w(f1))
      expect(server.properties['Availability']).to eq('up')
      expect(server.properties['Calculated Server State']).to eq(server.properties['Server State'])
    end

    it 'assigns status reported by metric to a server when its availability metric is something else than "up"' do
      parser.fetch_server_availabilities(%w(f1))
      expect(server.properties['Availability']).to eq('arbitrary value')
      expect(server.properties['Calculated Server State']).to eq('arbitrary value')
    end

    it 'assigns unknown status to a server with a missing metric' do
      allow(parser).to receive(:fetch_availabilities_for)
        .and_yield(server, nil)

      parser.fetch_server_availabilities(%w(f1))
      expect(server.properties['Availability']).to eq('unknown')
      expect(server.properties['Calculated Server State']).to eq('unknown')
    end
  end

  describe 'alternate_machine_id' do
    it 'should transform machine ID to dmidecode BIOS UUID' do
      # the /etc/machine-id is usually in downcase, and the dmidecode BIOS UUID is usually upcase
      # the alternate_machine_id should *just* swap digits, it should not handle upcase/downcase.
      # 33D1682F-BCA4-4B4C-B19E-CB47D344746C is a real BIOS UUID retrieved from a VM
      # 33d1682f-bca4-4b4c-b19e-cb47d344746c is what other providers store in the DB
      # 2f68d133a4bc4c4bb19ecb47d344746c is the machine ID for the BIOS UUID above
      # at the Middleware Provider, we get the second version, while the first is usually used by other providers
      machine_id = '2f68d133a4bc4c4bb19ecb47d344746c'
      expected = '33d1682f-bca4-4b4c-b19e-cb47d344746c'
      expect(parser.alternate_machine_id(machine_id)).to eq(expected)

      # and now we reverse the operation, just as a sanity check
      machine_id = '33d1682fbca44b4cb19ecb47d344746c'
      expected = '2f68d133-a4bc-4c4b-b19e-cb47d344746c'
      expect(parser.alternate_machine_id(machine_id)).to eq(expected)
    end
  end

  describe 'swap_part' do
    it 'should swap and reverse every two bytes of a machine ID part' do
      # the /etc/machine-id is usually in downcase, and the dmidecode BIOS UUID is usually upcase
      # the alternate_machine_id should *just* swap digits, it should not handle upcase/downcase.
      # 33D1682F-BCA4-4B4C-B19E-CB47D344746C is a real BIOS UUID retrieved from a VM
      # 33d1682f-bca4-4b4c-b19e-cb47d344746c is what other providers store in the DB
      # 2f68d133a4bc4c4bb19ecb47d344746c is the machine ID for the BIOS UUID above
      # at the Middleware Provider, we get the second version, while the first is usually used by other providers
      part = '2f68d133'
      expected = '33d1682f'
      expect(parser.swap_part(part)).to eq(expected)

      # and now we reverse the operation, just as a sanity check
      part = '33d1682f'
      expected = '2f68d133'
      expect(parser.swap_part(part)).to eq(expected)
    end
  end

  describe 'handle_no_machine_id' do
    it 'should_find_nil_for_nil' do
      expect(parser.find_host_by_bios_uuid(nil)).to be_nil
    end

    it 'should_alternate_nil_for_nil' do
      expect(parser.alternate_machine_id(nil)).to be_nil
    end
  end
end
