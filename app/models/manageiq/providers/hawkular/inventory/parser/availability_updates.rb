module ManageIQ::Providers
  class Hawkular::Inventory::Parser::AvailabilityUpdates < ManagerRefresh::Inventory::Parser
    def parse
      fetch_deployment_availabilities
    end

    def fetch_deployment_availabilities
      collector.deployment_updates.each do |item|
        deployment = persister.middleware_deployments.find_or_build(item.manager_ref[:ems_ref])
        deployment.status = item.options[:status]
      end
    end
  end
end
