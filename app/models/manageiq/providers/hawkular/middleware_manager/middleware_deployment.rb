module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareDeployment < MiddlewareDeployment
    def self.resource_path_for_metrics(item)
      path = ::Hawkular::Inventory::CanonicalPath.parse(item.ems_ref)
      # for subdeployments use it's parent deployment availability.
      path = path.up if URI.decode(path.resource_ids.last).include? '/subdeployment='
      # Ensure consistency on keys (resource_path) used on metric_id_by_resource_path
      path = ::Hawkular::Inventory::CanonicalPath.new(:tenant_id    => path.tenant_id,
                                                      :feed_id      => path.feed_id,
                                                      :resource_ids => path.resource_ids)
      path.to_s
    end
  end
end
