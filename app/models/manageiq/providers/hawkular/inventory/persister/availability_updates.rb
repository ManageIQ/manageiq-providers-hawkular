module ManageIQ::Providers
  class Hawkular::Inventory::Persister::AvailabilityUpdates < Hawkular::Inventory::Persister::MiddlewareManager
    def self.save_deployments(ems, collection)
      ::ActiveRecord::Base.transaction do
        collection.to_a.each do |item|
          deployment = ::ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDeployment.find_by(
            :ext_management_system => ems, :ems_ref => item.manager_uuid
          )

          next unless deployment # if deployment is not found in the database, it is ignored.

          $mw_log.debug("EMS_#{ems.id}(Persister::AvailabilityUpdates): " \
                        "Updating status #{deployment.status} -> #{item.status} for deployment #{deployment.ems_ref}")

          deployment.status = item.status
          deployment.save!
        end
      end
    end

    # has_middleware_manager_servers
    has_middleware_manager_deployments(:custom_save_block => method(:save_deployments))
  end
end
