module ManageIQ::Providers
  class Hawkular::Inventory::Persister::AvailabilityUpdates < Hawkular::Inventory::Persister::MiddlewareManager
    def self.save_deployments(ems, collection)
      save_resource(ems, collection, :deployment) do |deployment, item|
        deployment.status = item.status
      end
    end

    def self.save_servers(ems, collection)
      save_resource(ems, collection, :server) do |server, item|
        data_to_update = item.properties.try(:slice, 'Server State', 'Availability', 'Calculated Server State')
        next if data_to_update.blank?

        server.properties = {} if server.properties.blank?
        server.properties.merge!(data_to_update)
      end
    end

    def self.save_domains(ems, collection)
      save_resource(ems, collection, :domain) do |domain, item|
        domain.availability = item.properties['Availability']
      end
    end

    def self.save_resource(ems, collection, resource_name)
      ::ActiveRecord::Base.transaction do
        collection.to_a.each do |item|
          resource = ems.send("middleware_#{resource_name.to_s.pluralize}").find_by(:ems_ref => item.manager_uuid)
          next unless resource

          $mw_log.debug("EMS_#{ems.id}(Persister::AvailabilityUpdates): " \
                        "Updating availability #{resource.properties} -> #{resource.properties} for #{resource_name} #{resource.ems_ref}")

          yield(resource, item)
          resource.save!
        end
      end
    end

    has_middleware_manager_deployments(:custom_save_block => method(:save_deployments))
    has_middleware_manager_servers(:custom_save_block => method(:save_servers))
    has_middleware_manager_domains(:custom_save_block => method(:save_domains))
  end
end
