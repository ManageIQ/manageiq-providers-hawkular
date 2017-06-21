module ManageIQ::Providers
  class Hawkular::Inventory::Persister::AvailabilityUpdates < Hawkular::Inventory::Persister::MiddlewareManager
    def self.save_deployments(ems, collection)
      ::ActiveRecord::Base.transaction do
        collection.to_a.each do |item|
          deployment = ems.middleware_deployments.find_by(:ems_ref => item.manager_uuid)
          next unless deployment # if deployment is not found in the database, it is ignored.

          $mw_log.debug("EMS_#{ems.id}(Persister::AvailabilityUpdates): " \
                        "Updating status #{deployment.status} -> #{item.status} for deployment #{deployment.ems_ref}")

          deployment.status = item.status
          deployment.save!
        end
      end
    end

    def self.save_servers(ems, collection)
      ::ActiveRecord::Base.transaction do
        collection.to_a.each do |item|
          data_to_update = item.properties.try(:slice, 'Server State', 'Availability', 'Calculated Server State')
          next if data_to_update.blank?

          server = ems.middleware_servers.find_by(:ems_ref => item.manager_uuid)
          next unless server # if no matching server is in the database, there is nothing to update

          $mw_log.debug("EMS_#{ems.id}(Persister::AvailabilityUpdates): " \
                        "Updating status to #{item.properties} for server #{server.ems_ref}")

          server.properties = {} if server.properties.blank?
          server.properties.merge!(data_to_update)
          server.save!
        end
      end
    end

    has_middleware_manager_deployments(:custom_save_block => method(:save_deployments))
    has_middleware_manager_servers(:custom_save_block => method(:save_servers))
  end
end
