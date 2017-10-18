module OperationDispatcher
  # server ops
  def shutdown_middleware_server(ems_ref, params = {})
    timeout = params[:timeout] || 0
    run_generic_operation(:Shutdown, ems_ref, :restart => false, :timeout => timeout)
  end

  def suspend_middleware_server(ems_ref, params = {}, extra_data = {})
    timeout = params[:timeout] || 0
    run_generic_operation(:Suspend, ems_ref, {:timeout => timeout}, extra_data)
  end

  def resume_middleware_server(ems_ref, extra_data = {})
    run_generic_operation(:Resume, ems_ref, {}, extra_data)
  end

  def reload_middleware_server(ems_ref, extra_data = {})
    run_generic_operation(:Reload, ems_ref, {}, extra_data)
  end

  def stop_middleware_server(ems_ref)
    run_generic_operation(:Shutdown, ems_ref, {}, {:original_operation => :Stop})
  end

  def start_middleware_domain_server(ems_ref, extra_data = {})
    run_generic_operation(:Start, ems_ref, {}, extra_data)
  end

  def stop_middleware_domain_server(ems_ref, extra_data = {})
    run_generic_operation(:Stop, ems_ref, {}, extra_data)
  end

  def restart_middleware_server(ems_ref)
    run_generic_operation(:Shutdown, ems_ref, {:restart => true}, {:original_operation => :Restart})
  end

  # domain server ops
  def restart_middleware_domain_server(ems_ref, extra_data = {})
    run_generic_operation(:Restart, ems_ref, {}, extra_data)
  end

  def kill_middleware_domain_server(ems_ref, extra_data = {})
    run_generic_operation(:Kill, ems_ref, {}, extra_data)
  end

  # server group ops
  def start_middleware_server_group(ems_ref)
    run_generic_operation('Start Servers', ems_ref)
  end

  def stop_middleware_server_group(ems_ref, params = {})
    timeout = params[:timeout] || 0
    run_generic_operation('Stop Servers', ems_ref, :timeout => timeout)
  end

  def restart_middleware_server_group(ems_ref)
    run_generic_operation('Restart Servers', ems_ref)
  end

  def reload_middleware_server_group(ems_ref)
    run_generic_operation('Reload Servers', ems_ref)
  end

  def suspend_middleware_server_group(ems_ref, params = {})
    timeout = params[:timeout] || 0
    run_generic_operation('Suspend Servers', ems_ref, :timeout => timeout)
  end

  def resume_middleware_server_group(ems_ref)
    run_generic_operation('Resume Servers', ems_ref)
  end

  def create_jdr_report(ems_ref)
    run_generic_operation(:JDR, ems_ref)
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

      connection.operations(true).add_datasource(datasource_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Add Datasource',
          datasource_data[:datasourceName],
          ems_ref,
          MiddlewareServer
        )

        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
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

      connection.operations(true).add_deployment(deployment_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Deploy',
          deployment_data[:destination_file_name],
          ems_ref,
          MiddlewareServer
        )
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
    end
  end

  def undeploy_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name,
        :remove_content  => true
      }

      connection.operations(true).undeploy(deployment_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Undeploy',
          deployment_name,
          ems_ref,
          MiddlewareDeployment
        )

        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
    end
  end

  def disable_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      connection.operations(true).disable_deployment(deployment_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Disable Deployment',
          deployment_name,
          ems_ref,
          MiddlewareDeployment
        )
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
    end
  end

  def enable_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      connection.operations(true).enable_deployment(deployment_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Enable Deployment',
          deployment_name, ems_ref,
          MiddlewareDeployment
        )
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
    end
  end

  def restart_middleware_deployment(ems_ref, deployment_name)
    with_provider_connection do |connection|
      deployment_data = {
        :resource_path   => ems_ref.to_s,
        :deployment_name => deployment_name
      }

      connection.operations(true).restart_deployment(deployment_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Restart Deployment',
          deployment_name,
          ems_ref,
          MiddlewareDeployment
        )
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
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

      connection.operations(true).add_jdbc_driver(driver_data) do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          'Add JDBC Driver',
          driver_data[:driver_name],
          ems_ref,
          MiddlewareServer
        )
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end
        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end
    end
  end

  def remove_middleware_datasource(ems_ref)
    run_specific_operation('RemoveDatasource', ems_ref)
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

  #
  # this method send a specific command to the server
  # with his own JSON. this doesn't use ExecuteOperation.
  #
  def run_specific_operation(operation_name, ems_ref, parameters = {})
    parameters[:resourcePath] = ems_ref.to_s
    run_operation(parameters, operation_name)
  end

  def run_operation(parameters, operation_name = nil, extra_data = {})
    with_provider_connection do |connection|
      callback = proc do |on|
        notification_args = NotificationArgs.new(
          :mw_op_success,
          extra_data[:original_operation] || parameters[:operationName],
          nil,
          extra_data[:original_resource_path] || parameters[:resourcePath],
          MiddlewareServer
        )

        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          emit_middleware_notification(notification_args)
        end

        on.failure do |error|
          _log.error 'error callback was called, reason: ' + error.to_s
          notification_args.type = :mw_op_failure
          notification_args.detailed_message = error.to_s
          emit_middleware_notification(notification_args)
        end
      end

      operation_connection = connection.operations(true)
      if operation_name.nil?
        operation_connection.invoke_generic_operation(parameters, &callback)
      else
        operation_connection.invoke_specific_operation(parameters, operation_name, &callback)
      end
    end
  end

  def emit_middleware_notification(notification_args)
    MiddlewareNotification.new(notification_args, self).emit
  end
end
