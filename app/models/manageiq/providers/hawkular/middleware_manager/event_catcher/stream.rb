class ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream
  def initialize(ems)
    @ems               = ems
    @alerts_client     = ems.alerts_client
    @metrics_client    = ems.metrics_client
    @inventory_client  = ems.inventory_client
    @collecting_events = false
  end

  def start
    @collecting_events = true
  end

  def stop
    @collecting_events = false
  end

  def each_batch
    while @collecting_events
      yield fetch
    end
  end

  private

  def fetch
    events = []
    events = fetch_events
    events.concat(fetch_availabilities)
  rescue => err
    $mw_log.warn "#{log_prefix} Error capturing events #{err}"
    events
  end

  # Each fetch is performed from the time of the most recently caught event or 1 minute back for the first poll.
  # This gives us some slack if hawkular events are timestamped behind the miq server time.
  # Note: This assumes all Hawkular events at max-time T are fetched in one call. It is unlikely that there
  # would be more than one for the same millisecond, and that the query would be performed in the midst of
  # writes for the same ms. It may be a feasible scenario but I think it's unnecessary to handle it at this time.
  def fetch_events
    @start_time ||= (Time.current - 1.minute).to_i * 1000
    $mw_log.debug "#{log_prefix} Catching Events since [#{@start_time}]"

    new_events = @alerts_client.list_events("startTime" => @start_time, "tags" => "miq.event_type|*", "thin" => true)
    @start_time = new_events.max_by(&:ctime).ctime + 1 unless new_events.empty? # add 1 ms to avoid dups with GTE filter
    new_events
  end

  def fetch_availabilities
    parser = ManageIQ::Providers::Hawkular::Inventory::Parser::MiddlewareManager.new
    parser.collector = ManageIQ::Providers::Hawkular::Inventory::Collector::MiddlewareManager.new(@ems, nil)

    server_avails = fetch_server_availabilities(parser)
    deploy_avails = fetch_deployment_availabilities(parser)

    server_avails.concat(deploy_avails)
  end

  def fetch_server_availabilities(parser)
    # For servers, it's also needed to refresh server states from inventory.
    $mw_log.debug("#{log_prefix} Retrieving server states from Hawkular inventory")

    server_states = {}
    @ems.middleware_servers.reload.each do |server|
      inventoried_server = @inventory_client.get_resource(server.ems_ref, true)
      server_states[server.id] = inventoried_server.try(:properties).try(:[], 'Server State') || ''
    end

    # Fetch availabilities and process them together with server state updates.
    fetch_entities_availabilities(parser, @ems.middleware_servers) do |item, avail|
      server_state = server_states[item.id]
      avail_data, calculated_status = parser.process_server_availability(server_state, avail)

      props = item.try(:properties)
      stored_avail = props.try(:[], 'Availability')
      stored_state = props.try(:[], 'Server State')
      stored_calculated = props.try(:[], 'Calculated Server State')

      next nil if stored_avail == avail_data && stored_calculated == calculated_status && stored_state == server_state

      {
        :ems_ref     => item.ems_ref,
        :association => :middleware_servers,
        :data        => {
          'Availability'            => avail_data,
          'Server State'            => server_state,
          'Calculated Server State' => calculated_status
        }
      }
    end
  end

  def fetch_deployment_availabilities(parser)
    fetch_entities_availabilities(parser, @ems.middleware_deployments.reload) do |item, avail|
      status = parser.process_deployment_availability(avail)
      next nil if item.status == status

      {
        :ems_ref     => item.ems_ref,
        :association => :middleware_deployments,
        :data        => {
          :status => status
        }
      }
    end
  end

  def fetch_entities_availabilities(parser, entities)
    return [] if entities.blank?
    log_name = entities.first.class.name.demodulize

    # Get feeds where availabilities should be looked in.
    feeds = entities.map(&:feed).uniq

    $mw_log.debug("#{log_prefix} Retrieving availabilities for #{entities.count} " \
                  "#{log_name.pluralize(entities.count)} in #{feeds.count} feeds.")

    # Get availabilities
    avails = {}
    parser.fetch_availabilities_for(feeds, entities, entities.first.class::AVAIL_TYPE_ID) do |item, avail|
      avail_data = avail.try(:[], 'data').try(:first)
      avails[item.id] = yield(item, avail_data)

      # Filter out if availability is unchanged. This way, no refresh is triggered if unnecessary.
      avails.delete(item.id) unless avails[item.id]
    end

    $mw_log.debug("#{log_prefix} Availability has changed for #{avails.length} #{log_name.pluralize(avails.length)}.")
    avails.values
  end

  def log_prefix
    @_log_prefix ||= "EMS_#{@ems.id}(Hawkular::EventCatcher::Stream)"
  end
end
