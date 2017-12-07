module ManageIQ
  module Providers
    module Hawkular
      module Inventory
        class OperationNotification
          attr_reader :args, :manager

          def initialize(args, manager)
            @args = args
            @manager = manager
          end

          def emit
            ActiveRecord::Base.connection_pool.with_connection do
              mw_entity = args.entity_klass.find_by(:ems_ref => args.target_resource) unless args.entity_klass == MiddlewareServer
              mw_server = if mw_entity.nil?
                            MiddlewareServer.find_by(:ems_ref => args.target_resource) ||
                              MiddlewareDomain.find_by(:ems_ref => args.target_resource)
                          else
                            MiddlewareServer.find_by(:id => mw_entity.server_id)
                          end

              return unless mw_server

              Notification.create(
                :type => args.type, :options => {
                  :op_name   => args.operation_name,
                  :op_arg    => args.operation_args || '',
                  :mw_server => "#{mw_server.name} (#{mw_server.feed})"
                }
              )

              unless mw_entity
                EmsEvent.add_queue(
                  'add', manager.id,
                  :ems_id          => manager.id,
                  :source          => 'HAWKULAR',
                  :timestamp       => Time.zone.now,
                  :event_type      => args.event_type(mw_server),
                  :message         => args.event_message(mw_server),
                  :middleware_ref  => mw_server.ems_ref,
                  :middleware_type => mw_server.class.name.demodulize
                )
              end
            end
          end
        end
      end
    end
  end
end
