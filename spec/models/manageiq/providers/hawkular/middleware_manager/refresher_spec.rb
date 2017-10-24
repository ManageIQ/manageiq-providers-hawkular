require_relative 'hawkular_helper'

describe ManageIQ::Providers::Hawkular::MiddlewareManager::Refresher do
  before do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    @ems_hawkular = FactoryGirl.create(:ems_hawkular,
                                       :hostname        => 'localhost',
                                       :port            => 8080,
                                       :authentications => [auth])
    @ems_hawkular2 = FactoryGirl.create(:ems_hawkular,
                                        :hostname        => '127.0.0.1',
                                        :port            => 8080,
                                        :authentications => [auth])
    @vm = FactoryGirl.create(:vm_redhat,
                             :uid_ems => '94f76aa25a3a')
  end

  it "will perform a full refresh on localhost" do
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems_hawkular)
    end

    @ems_hawkular.reload

    expect(@ems_hawkular.middleware_domains).not_to be_empty
    domain = @ems_hawkular.middleware_domains.first
    expect(domain.middleware_server_groups).not_to be_empty
    expect(@ems_hawkular.middleware_servers).not_to be_empty

    # TODO: Restore these expectations
    # check whether the server was associated with the vm
    # server = @ems_hawkular.middleware_servers.first
    # expect(server.lives_on_id).to eql(@vm.id)
    # expect(server.lives_on_type).to eql(@vm.type)
    expect(@ems_hawkular.middleware_deployments).not_to be_empty
    expect(@ems_hawkular.middleware_datasources).not_to be_empty
    expect(@ems_hawkular.middleware_messagings).not_to be_empty
    expect(@ems_hawkular.middleware_deployments.first.status).to eq('Enabled')
    expect(@ems_hawkular.middleware_servers.first.properties).to include(
      'Availability'            => 'up',
      'Calculated Server State' => 'running'
    )
    assert_specific_datasource(@ems_hawkular, 'Local~/subsystem=datasources/data-source=ExampleDS')
    assert_specific_datasource(@ems_hawkular,
                               'Local~/host=master/server=server-one/subsystem=datasources/data-source=ExampleDS')
    assert_specific_server_group(domain)
    assert_specific_domain_server
    assert_specific_domain
  end

  def assert_specific_datasource(ems, nativeid)
    datasource = ems.middleware_datasources.find_by(:nativeid => nativeid)
    expect(datasource.name).to eq('Datasource [ExampleDS]')
    expect(datasource.nativeid).to eq(nativeid)
    expect(datasource.properties).to include(
      'Driver Name' => 'h2',
      'JNDI Name'   => 'java:jboss/datasources/ExampleDS',
      'Enabled'     => 'true'
    )
  end

  def assert_specific_domain
    domain = @ems_hawkular.middleware_domains.find_by(:feed => 'master.Unnamed%20Domain')
    expect(domain.name).to eq('Unnamed Domain')
    expect(domain.nativeid).to eq('Local~/host=master')

    expect(domain.properties).not_to be_nil
    expect(domain.properties).to include(
      'Running Mode'         => 'NORMAL',
      'Host State'           => 'running',
      'Is Domain Controller' => 'true',
    )
  end

  def assert_specific_server_group(domain)
    server_group = domain.middleware_server_groups.find_by(:name => 'main-server-group')
    expect(server_group.name).to eq('main-server-group')
    expect(server_group.nativeid).to eq('Local~/server-group=main-server-group')
    expect(server_group.profile).to eq('full')
    expect(server_group.properties).not_to be_nil
    expect(server_group.middleware_deployments).to be_empty
    expect(server_group.ext_management_system).to eq(@ems_hawkular)
  end

  def assert_specific_domain_server
    server = @ems_hawkular.middleware_servers.find_by(:name => 'server-one')
    expect(server.name).to eq('server-one')
    expect(server.nativeid).to eq('Local~/host=master/server=server-one')
    expect(server.product).to eq('WildFly Full')
    expect(server.hostname).to eq(the_domain_feed_id)
    expect(server.properties).not_to be_nil
  end

  it 'will perform a full refresh on 127.0.0.1 even though the os type is not there yet' do
    # using different cassette that represents the hawkular inventory without the operating system resource type
    # TODO: Make this work with live tests
    VCR.use_cassette(described_class.name.underscore.to_s + '_without_os',
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true,
                     :record                         => :none) do
      EmsRefresh.refresh(@ems_hawkular2)
    end

    @ems_hawkular2.reload
    expect(@ems_hawkular2.middleware_domains).to be_empty
    expect(@ems_hawkular2.middleware_servers).not_to be_empty
    server = @ems_hawkular2.middleware_servers.first
    expect(server.lives_on_id).to be_nil
    expect(server.lives_on_type).to be_nil
    expect(@ems_hawkular2.middleware_deployments).not_to be_empty
    expect(@ems_hawkular2.middleware_datasources).not_to be_empty
    expect(@ems_hawkular2.middleware_messagings).not_to be_empty
    assert_specific_datasource(@ems_hawkular2, 'Local~/subsystem=datasources/data-source=ExampleDS')
  end

  describe "#preprocess_targets" do
    let(:ems_hawkular) { FactoryGirl.create(:ems_hawkular) }
    let(:ems_hawkular2) { FactoryGirl.create(:ems_hawkular) }
    let(:target_server) do
      ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_servers,
        :manager_ref => { :ems_ref => 'abc' }
      )
    end
    let(:target_deployment) do
      ManagerRefresh::Target.new(
        :manager     => ems_hawkular,
        :association => :middleware_deployments,
        :manager_ref => { :ems_ref => 'def' }
      )
    end

    it "must fallback to just one full graph refresh if ems is a target" do
      # Set-up
      targets = [target_server, ems_hawkular]
      refresher = described_class.new(targets)

      # Try
      refresher.preprocess_targets

      # Validate
      expect(refresher.targets_by_ems_id.count).to eq(1)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].count).to eq(1)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].first).to eq(ems_hawkular)
    end

    it "must group multiple availability refreshes in one target" do
      # Set-up
      targets = [target_server, target_deployment]
      refresher = described_class.new(targets)

      # Try
      refresher.preprocess_targets

      # Validate
      expect(refresher.targets_by_ems_id.count).to eq(1)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].count).to eq(1)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].first)
        .to be_kind_of(::ManageIQ::Providers::Hawkular::Inventory::AvailabilityUpdates)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].first.targets)
        .to contain_exactly(target_server, target_deployment)
    end

    it "must handle correctly a refresh of two managers" do
      # Set-up
      targets = [
        target_server,
        ems_hawkular
      ]
      targets << ManagerRefresh::Target.new(
        :manager     => ems_hawkular2,
        :association => :middleware_servers,
        :manager_ref => { :ems_ref => 'abc' }
      )

      # Try
      refresher = described_class.new(targets)
      refresher.preprocess_targets

      # Validate
      expect(refresher.targets_by_ems_id.count).to eq(2)
      expect(refresher.targets_by_ems_id[ems_hawkular.id].first).to be(ems_hawkular)
      expect(refresher.targets_by_ems_id[ems_hawkular2.id].first)
        .to be_kind_of(::ManageIQ::Providers::Hawkular::Inventory::AvailabilityUpdates)
    end
  end
end
