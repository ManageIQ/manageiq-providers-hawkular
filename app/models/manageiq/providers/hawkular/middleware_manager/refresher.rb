module ManageIQ::Providers::Hawkular
  class MiddlewareManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def preprocess_targets
      @targets_by_ems_id.each do |ems_id, targets|
        if targets.any? { |t| t.kind_of?(ExtManagementSystem) }
          # If the EMS is in the list of targets, full graph refresh is done.
          ems = @ems_by_ems_id[ems_id]
          _log.info "Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}]." if targets.length > 1
          targets.clear << ems
        elsif targets.any?
          # Assuming availabilities are being refreshed (since there is no other
          # kind of refresh for Hawkular)

          # Filter out duplicated entities
          # The reverse is to keep the most up-to-date data
          uniq_targets = targets.reverse.uniq do |item|
            {
              :association => item.association,
              :ems_ref     => item.manager_ref[:ems_ref]
            }
          end

          # Compact all availability updates into one target
          targets.clear
          targets << ::ManageIQ::Providers::Hawkular::Inventory::AvailabilityUpdates.new(uniq_targets)
        end
      end
    end
  end
end
