class ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream
  def initialize(ems)
    @ems               = ems
    @alerts_client     = ems.alerts_client
    @metrics_client    = ems.metrics_client
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
    events = fetch_events
    availabilities = fetch_availabilities

    events.concat(availabilities)
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
  rescue => err
    $mw_log.warn "#{log_prefix} Error capturing events #{err}"
    []
  end

  def fetch_availabilities
    parser = ManageIQ::Providers::Hawkular::Inventory::Parser::MiddlewareManager.new
    parser.collector = ManageIQ::Providers::Hawkular::Inventory::Collector::MiddlewareManager.new(@ems, nil)

    fetch_deployment_availabilities(parser)
  end

  def fetch_deployment_availabilities(parser)
    # Get list of deployments to retrieve its availabilities
    deploys = @ems.middleware_deployments.all
    feeds = deploys.map(&:feed).uniq

    $mw_log.debug("#{log_prefix} Retrieving availabilities for #{deploys.count} deployments in #{feeds.count} feeds.")

    # Get deployment availabilities
    avails = {}
    parser.fetch_availabilities_for(feeds, deploys, parser.class::DEPLOYMENTS_AVAIL_TYPE_ID) do |item, avail|
      avail_data = avail.try(:[], 'data').try(:first)
      avails[item.id] = {
        :ems_ref      => item.ems_ref,
        :association  => :middleware_deployments,
        :availability => avail_data,
        :status       => parser.process_deployment_availability(avail_data)
      }

      # Filter out if availability is unchanged. This way, no refresh is triggered if unnecessary.
      avails.delete(item.id) if item.status == avails[item.id][:status]
    end

    $mw_log.debug("#{log_prefix} Availability has changed for #{avails.length} deployments.")
    avails.values
  end

  def log_prefix
    @_log_prefix ||= "EMS_#{@ems.id}(Hawkular::EventCatcher::Stream)"
  end
end
