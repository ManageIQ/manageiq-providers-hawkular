module OperationDispatcher
  module DSL
    def group_operation(name, action_name)
      define_method("#{name}_middleware_server_group") do |ems_ref|
        run_generic_operation(action_name.to_sym, ems_ref)
      end
    end

    def domain_operation(name, action_name, _ = {}, default_extra_data = {})
      define_method("#{name}_middleware_domain_server") do |ems_ref, extra_data = {}|
        run_generic_operation(action_name.to_sym, ems_ref, {}, default_extra_data.merge(extra_data))
      end
    end

    def standalone_operation(name, action_name, default_params = {}, default_extra_data = {})
      define_method("#{name}_middleware_server") do |ems_ref, params = {}, extra_data = {}|
        run_generic_operation(action_name.to_sym, ems_ref, default_params.merge(params), default_extra_data.merge(extra_data))
      end
    end

    def generic_operation(name, action_name)
      define_method(name) { |ref| run_generic_operation(action_name.to_sym, ref) }
    end

    def specific_operation(name, action_name, default_params = {})
      define_method(name) do |ref, params = {}|
        params[:resourcePath] = ref.to_s
        run_operation(default_params.merge(params), action_name)
      end
    end
  end

  def self.included(base)
    base.extend(DSL)
  end

  def add_middleware_datasource(ems_ref, hash)
    with_provider_connection do |connection|
      datasource_data = {
        :resourcePath         => ems_ref.to_s,
        :datasourceName       => hash[:datasource]["datasourceName"],
        :xaDatasource         => hash[:datasource]["xaDatasource"],
        :jndiName             => hash[:datasource]["jndiName"],
        :driverName           => hash[:datasource]["driverName"],
        :driverClass          => hash[:datasource]["driverClass"],
        :connectionUrl        => hash[:datasource]["connectionUrl"],
        :userName             => hash[:datasource]["userName"],
        :password             => hash[:datasource]["password"],
        :xaDataSourceClass    => hash[:datasource]["driverClass"],
        :securityDomain       => hash[:datasource]["securityDomain"],
        :datasourceProperties => hash[:datasource]["datasourceProperties"]
      }

      notification_args = NotificationArgs.success(
        'Add Datasource',
        datasource_data[:datasourceName],
        ems_ref,
        MiddlewareServer
      )

      connection.operations(true).add_datasource(datasource_data, &callback_for(notification_args))
    end
  end

  def add_middleware_deployment(ems_ref, hash)
    with_provider_connection do |connection|
      deployment_data = {
        :enabled               => hash[:file]["enabled"],
        :force_deploy          => hash[:file]["force_deploy"],
        :destination_file_name => hash[:file]["runtime_name"] || hash[:file]["file"].original_filename,
        :binary_content        => hash[:file]["file"].read,
        :resource_path         => ems_ref.to_s
      }

      unless hash[:file]['server_groups'].nil?
        # in case of deploying into server group the resource path should point to the domain controller
        deployment_data[:server_groups] = hash[:file]['server_groups']
        server_group_path_hash = ::Hawkular::Inventory::CanonicalPath.parse(deployment_data[:resource_path]).to_h
        server_group_path_hash[:resource_ids].slice!(1..-1)
        host_controller_path = ::Hawkular::Inventory::CanonicalPath.new(server_group_path_hash)
        deployment_data[:resource_path] = host_controller_path.to_s
      end

      notification_args = NotificationArgs.success(
        'Deploy',
        deployment_data[:destination_file_name],
        ems_ref,
        MiddlewareServer
      )

      connection.operations(true).add_deployment(deployment_data, &callback_for(notification_args))
    end
  end

  def undeploy_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name,
        :remove_content  => true
      }

      notification_args = NotificationArgs.success(
        'Undeploy',
        deployment_name,
        ems_ref,
        MiddlewareDeployment
      )

      connection.operations(true).undeploy(deployment_data, &callback_for(notification_args))
    end
  end

  def disable_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      notification_args = NotificationArgs.success(
        'Disable Deployment',
        deployment_name,
        ems_ref,
        MiddlewareDeployment
      )

      connection.operations(true).disable_deployment(deployment_data, &callback_for(notification_args))
    end
  end

  def enable_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      notification_args = NotificationArgs.success(
        'Enable Deployment',
        deployment_name, ems_ref,
        MiddlewareDeployment
      )

      connection.operations(true).enable_deployment(deployment_data, &callback_for(notification_args))
    end
  end

  def restart_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      notification_args = NotificationArgs.success(
        'Restart Deployment',
        deployment_name,
        ems_ref,
        MiddlewareDeployment
      )

      connection.operations(true).restart_deployment(deployment_data, &callback_for(notification_args))
    end
  end

  def add_middleware_jdbc_driver(ems_ref, hash)
    with_provider_connection do |connection|
      driver_data = {
        :driver_name          => hash[:driver]["driver_name"],
        :driver_jar_name      => hash[:driver]["driver_jar_name"] || hash[:driver]["file"].original_filename,
        :module_name          => hash[:driver]["module_name"],
        :driver_class         => hash[:driver]["driver_class"],
        :driver_major_version => hash[:driver]["driver_major_version"],
        :driver_minor_version => hash[:driver]["driver_minor_version"],
        :binary_content       => hash[:driver]["file"].read,
        :resource_path        => ems_ref.to_s
      }

      notification_args = NotificationArgs.success(
        'Add JDBC Driver',
        driver_data[:driver_name],
        ems_ref,
        MiddlewareServer
      )

      connection.operations(true).add_jdbc_driver(driver_data, &callback_for(notification_args))
    end
  end

  private

  # Trigger running a (Hawkular) operation on the
  # selected target server. This server is identified
  # by ems_ref, which in Hawkular terms is the
  # fully qualified resource path from Hawkular inventory
  #
  # this method execute an operation through ExecuteOperation request command.
  #
  def run_generic_operation(operation_name, ems_ref, parameters = {}, extra_data = {})
    the_operation = {
      :operationName => operation_name,
      :resourcePath  => ems_ref.to_s,
      :parameters    => parameters
    }
    run_operation(the_operation, nil, extra_data)
  end

  def callback_for(notification_args)
    proc do |on|
      on.success do |data|
        _log.debug("Success on websocket-operation #{data}")

        emit_middleware_notification(notification_args)
      end

      on.failure do |error|
        _log.error("error callback was called, reason: #{error}")

        notification_args.type = :mw_op_failure
        notification_args.detailed_message = error.to_s
        emit_middleware_notification(notification_args)
      end
    end
  end

  def run_operation(parameters, operation_name = nil, extra_data = {})
    with_provider_connection do |connection|
      notification_args = NotificationArgs.success(
        extra_data[:original_operation] || parameters[:operationName],
        nil,
        extra_data[:original_resource_path] || parameters[:resourcePath],
        MiddlewareServer
      )

      operation_connection = connection.operations(true)
      if operation_name.nil?
        operation_connection.invoke_generic_operation(parameters, &callback_for(notification_args))
      else
        operation_connection.invoke_specific_operation(parameters, operation_name, &callback_for(notification_args))
      end
    end
  end

  def emit_middleware_notification(notification_args)
    MiddlewareNotification.new(notification_args, self).emit
  end
end
