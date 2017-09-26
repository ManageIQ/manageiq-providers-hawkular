module ManageIQ::Providers
  class Hawkular::Inventory::Parser::AvailabilityUpdates < ManagerRefresh::Inventory::Parser
    def parse
      fetch_server_availabilities
      fetch_deployment_availabilities
      fetch_domain_availabilities
    end

    private

    def fetch_server_availabilities
      collector.server_updates.each do |item|
        server = persister.middleware_servers.find_or_build(item.manager_ref[:ems_ref])
        server.properties = item.options
      end
    end

    def fetch_deployment_availabilities
      collector.deployment_updates.each do |item|
        deployment = persister.middleware_deployments.find_or_build(item.manager_ref[:ems_ref])
        deployment.status = item.options[:status]
      end
    end

    def fetch_domain_availabilities
      collector.domain_updates.each do |item|
        domain = persister.middleware_domains.find_or_build(item.manager_ref[:ems_ref])
        domain.properties = item.options
      end
    end
  end
end
