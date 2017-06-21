module ManageIQ::Providers
  class Hawkular::Inventory::AvailabilityUpdates
    attr_reader :targets

    delegate :select, :to => :targets
    delegate :<<, :to => :targets

    def initialize(targets)
      @targets = targets
    end

    def name
      "Collection of availabilities to update on inventory entities"
    end

    def id
      "Collection: #{@targets.map(&:manager_ref)}"
    end
  end
end
