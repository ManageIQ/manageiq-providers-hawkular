# TODO: remove the module and just make this:
# class ManageIQ::Providers::Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require 'hawkular/hawkular_client'

    require_nested :AlertManager
    require_nested :AlertProfileManager
    require_nested :EventCatcher
    require_nested :LiveMetricsCapture
    require_nested :MiddlewareDeployment
    require_nested :MiddlewareDatasource
    require_nested :MiddlewareMessaging
    require_nested :MiddlewareServer
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin
    include Inventory::ServerOperations
    include ::Hawkular::ClientUtils

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT

    has_many :middleware_domains, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_servers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_deployments, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_datasources, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_messagings, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_server_groups, :through => :middleware_domains

    standalone_operation :shutdown, 'Shutdown'
    standalone_operation :suspend, 'Suspend'
    standalone_operation :resume, 'Resume'
    standalone_operation :reload, 'Reload'
    standalone_operation :stop, 'Shutdown', {}, :original_operation => :Stop
    standalone_operation :restart, 'Shutdown', { :restart => true }, :original_operation => :Restart

    domain_operation :start, 'Start'
    domain_operation :stop, 'Stop'
    domain_operation :restart, 'Restart'
    domain_operation :kill, 'Kill'

    group_operation :start, 'Start Servers'
    group_operation :stop, 'Stop Servers'
    group_operation :restart, 'Restart Servers'
    group_operation :reload, 'Reload Servers'
    group_operation :suspend, 'Suspend Servers'
    group_operation :resume, 'Resume Servers'

    generic_operation :create_jdr_report, 'JDR'

    attr_accessor :client

    def verify_credentials(_auth_type = nil, options = {})
      begin
        # As the connect will only give a handle
        # we verify the credentials via an actual operation
        connect(options).inventory.list_feeds
      rescue URI::InvalidComponentError
        raise MiqException::MiqHostError, "Host '#{hostname}' is invalid"
      rescue ::Hawkular::ConnectionException
        raise MiqException::MiqUnreachableError, "Unable to connect to #{hostname}:#{port}"
      rescue ::Hawkular::Exception => he
        raise MiqException::MiqInvalidCredentialsError, 'Invalid credentials' if he.status_code == 401
        raise MiqException::MiqHostError, 'Hawkular not found on host' if he.status_code == 404
        raise MiqException::MiqCommunicationsError, he.message
      rescue => err
        $log.error(err)
        raise MiqException::Error, 'Unable to verify credentials'
      end

      true
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def self.verify_ssl_mode(security_protocol)
      case security_protocol
      when 'ssl-without-validation'
        OpenSSL::SSL::VERIFY_NONE
      else
        OpenSSL::SSL::VERIFY_PEER
      end
    end

    def self.entrypoint(host, port, security_protocol)
      case security_protocol
      when nil, '', 'non-ssl'
        URI::HTTP.build(:host => host, :port => port.to_i).to_s
      else
        URI::HTTPS.build(:host => host, :port => port.to_i).to_s
      end
    end

    # Hawkular Client
    def self.raw_connect(host, port, username, password, security_protocol, cert_store)
      credentials = {
        :username => username,
        :password => password
      }
      options = {
        :tenant         => 'hawkular',
        :verify_ssl     => verify_ssl_mode(security_protocol),
        :ssl_cert_store => cert_store
      }
      ::Hawkular::Client.new(:entrypoint => entrypoint(host, port, security_protocol),
                             :credentials => credentials, :options => options)
    end

    def connect(_options = {})
      @client ||= self.class.raw_connect(hostname,
                                         port,
                                         authentication_userid('default'),
                                         authentication_password('default'),
                                         default_endpoint.security_protocol,
                                         default_endpoint.ssl_cert_store)
    end

    def jdbc_drivers(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                        :resource_type_id => hawk_escape_id('JDBC Driver'))
        connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
      end
    end

    def child_resources(resource_path, recursive = false)
      with_provider_connection do |connection|
        connection.inventory.list_child_resources(resource_path, recursive)
      end
    end

    def metrics_resource(resource_path)
      with_provider_connection do |connection|
        connection.inventory.list_metrics_for_resource(resource_path)
      end
    end

    def metrics_client
      with_provider_connection(&:metrics)
    end

    def inventory_client
      with_provider_connection(&:inventory)
    end

    def operations_client
      with_provider_connection(&:operations)
    end

    def alerts_client
      with_provider_connection(&:alerts)
    end

    # UI methods for determining availability of fields
    def supports_port?
      true
    end

    def self.ems_type
      @ems_type ||= "hawkular".freeze
    end

    def self.description
      @description ||= "Hawkular".freeze
    end

    def self.event_monitor_class
      ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher
    end

    # To blacklist defined event types by default add them here...
    def self.default_blacklisted_event_names
      %w(
      )
    end

    def miq_id_prefix(id_to_prefix = "")
      "MiQ-region-#{miq_region.guid}-ems-#{guid}-#{id_to_prefix}"
    end

    def self.update_alert(*args)
      operation = args[0][:operation]
      alert = args[0][:alert]
      miq_alert = {
        :id          => alert.id,
        :enabled     => alert.enabled,
        :description => alert.description,
        :conditions  => alert.expression,
        :based_on    => alert.db
      }
      MiddlewareManager.find_each { |m| m.alert_manager.process_alert(operation, miq_alert) }
    end

    def self.update_alert_profile(*args)
      alert_profile_arg = args[0]
      miq_alert_profile = {
        :id                  => alert_profile_arg[:profile_id],
        :old_alerts_ids      => alert_profile_arg[:old_alerts],
        :new_alerts_ids      => alert_profile_arg[:new_alerts],
        :old_assignments_ids => process_old_assignments_ids(alert_profile_arg[:old_assignments]),
        :new_assignments_ids => process_new_assignments_ids(alert_profile_arg[:new_assignments])
      }
      MiddlewareManager.find_each do |m|
        m.alert_profile_manager.process_alert_profile(alert_profile_arg[:operation], miq_alert_profile)
      end
    end

    def alert_manager
      @alert_manager ||= ManageIQ::Providers::Hawkular::MiddlewareManager::AlertManager.new(self)
    end

    def alert_profile_manager
      @alert_profile_manager ||= ManageIQ::Providers::Hawkular::MiddlewareManager::AlertProfileManager.new(self)
    end

    def self.process_old_assignments_ids(old_assignments)
      old_assignments_ids = []
      unless old_assignments.empty?
        if old_assignments[0].class.name == "MiqEnterprise"
          MiddlewareManager.find_each { |m| m.middleware_servers.find_each { |eap| old_assignments_ids << eap.id } }
        else
          old_assignments_ids = old_assignments.collect(&:id)
        end
      end
      old_assignments_ids
    end

    def self.process_new_assignments_ids(new_assignments)
      new_assignments_ids = []
      unless new_assignments.nil? || new_assignments["assign_to"].nil?
        if new_assignments["assign_to"] == "enterprise"
          # Note that in this version the assign to enterprise is resolved at the moment of the assignment
          # In following iterations, enterprise assignment should be managed dynamically on the provider
          MiddlewareManager.find_each { |m| m.middleware_servers.find_each { |eap| new_assignments_ids << eap.id } }
        else
          new_assignments_ids = new_assignments["objects"]
        end
      end
      new_assignments_ids
    end
    private_class_method :process_old_assignments_ids, :process_new_assignments_ids
  end
end
