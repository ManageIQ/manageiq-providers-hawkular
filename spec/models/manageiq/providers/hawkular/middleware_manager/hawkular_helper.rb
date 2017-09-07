# Feed id to be used for all spec
def the_feed_id
  'wf-standalone'.freeze
end

def the_domain_feed_id
  'wf-domain'.freeze
end

def test_mw_manager_feed_id
  'mw-manager'.freeze
end

def test_machine_id
  # change me if needed during re-recording the vcrs
  'ee0137a08d38'.freeze
end

def test_start_time
  Time.new(2016, 10, 19, 8, 0, 0, "+00:00").freeze
end

def test_end_time
  Time.new(2016, 10, 19, 10, 0, 0, "+00:00").freeze
end

def test_hostname
  # 'hservices.torii.gva.redhat.com'.freeze
  'localhost'.freeze
end

def test_port
  # 80
  8080
end

def test_userid
  'jdoe'.freeze
end

def test_password
  'password'.freeze
end

def ems_hawkular_fixture
  _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
  auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
  FactoryGirl.create(:ems_hawkular,
                     :hostname        => test_hostname,
                     :port            => test_port,
                     :authentications => [auth],
                     :zone            => zone)
end
