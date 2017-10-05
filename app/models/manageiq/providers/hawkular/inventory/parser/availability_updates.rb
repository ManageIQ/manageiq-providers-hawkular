module ManageIQ::Providers
  class Hawkular::Inventory::Parser::AvailabilityUpdates < ManagerRefresh::Inventory::Parser
    def parse
      fetch_server_availabilities
      fetch_deployment_availabilities
      fetch_domain_availabilities
    end

    private

    def find_updated_resource(resource_name)
      collector.send("#{resource_name}_updates").each do |item|
        resource = persister.send("middleware_#{resource_name.to_s.pluralize}").find_or_build(item.manager_ref[:ems_ref])
        yield(resource, item)
      end
    end

    def fetch_server_availabilities
      find_updated_resource(:server) do |server, item|
        server.properties = item.options
      end
    end

    def fetch_deployment_availabilities
      find_updated_resource(:deployment) do |deployment, item|
        deployment.status = item.options[:status]
      end
    end

    def fetch_domain_availabilities
      find_updated_resource(:domain) do |domain, item|
        domain.properties = item.options
      end
    end
  end
end
