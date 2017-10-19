NotificationArgs = Struct.new(:type, :operation_name, :operation_args, :target_resource, :entity_klass, :detailed_message) do
  def self.success(*args)
    new(:mw_op_success, *args)
  end

  def event_type(entity)
    attributes = {
      :entity_type => entity.kind_of?(MiddlewareServer) ? 'MwServer' : 'MwDomain',
      :operation   => operation_name,
      :status      => type == :mw_op_success ? 'Success' : 'Failed'
    }

    '%{entity_type}.%{operation}.%{status}' % attributes
  end

  def event_message(entity)
    attributes = {
      :operation => operation_name,
      :server    => entity.name,
      :status    => type == :mw_op_success ? _('succeeded') : _('failed')
    }

    message = _('%{operation} operation for %{server} %{status}') % attributes

    message + ": #{detailed_message}" if detailed_message
  end
end
