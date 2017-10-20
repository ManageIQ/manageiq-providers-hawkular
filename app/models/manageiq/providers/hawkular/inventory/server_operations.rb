module ManageIQ
  module Providers
    module Hawkular
      module Inventory
        module ServerOperations
          extend ActiveSupport::Concern

          class_methods do
            def group_operation(name, *args)
              generic_operation("#{name}_middleware_server_group", *args)
            end

            def domain_operation(name, *args)
              generic_operation("#{name}_middleware_domain_server", *args)
            end

            def standalone_operation(name, *args)
              generic_operation("#{name}_middleware_server", *args)
            end

            def generic_operation(name, action_name, default_params = {}, default_extra_data = {})
              define_method(name) do |ems_ref, params = {}, extra_data = {}|
                run_generic_operation(action_name.to_sym, ems_ref, default_params.merge(params), default_extra_data.merge(extra_data))
              end
            end

            def specific_operation(name, action_name, default_params = {})
              define_method(name) do |ref, params = {}|
                params[:resourcePath] = ref.to_s
                run_operation(default_params.merge(params), action_name)
              end
            end
          end

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
            Inventory::OperationNotification.new(notification_args, self).emit
          end
        end
      end
    end
  end
end
