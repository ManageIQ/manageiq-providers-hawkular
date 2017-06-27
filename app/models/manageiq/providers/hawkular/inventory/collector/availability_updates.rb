module ManageIQ::Providers
  class Hawkular::Inventory::Collector::AvailabilityUpdates < ManagerRefresh::Inventory::Collector
    def deployment_updates
      @target.select { |item| item.association == :middleware_deployments }
    end

    def server_updates
      @target.select { |item| item.association == :middleware_servers }
    end
  end
end
