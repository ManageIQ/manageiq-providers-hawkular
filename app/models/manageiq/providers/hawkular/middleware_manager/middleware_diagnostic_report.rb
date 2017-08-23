require 'timeout'

module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareDiagnosticReport < ApplicationRecord
    self.table_name = 'middleware_diagnostic_reports'

    STATUS_QUEUED = 'Queued'.freeze
    STATUS_RUNNING = 'Running'.freeze
    STATUS_ERROR = 'Error'.freeze
    STATUS_READY = 'Ready'.freeze

    belongs_to :middleware_server
    has_one :binary_blob, :as => :resource, :dependent => :destroy

    validates :middleware_server_id, :requesting_user, :presence => true
    validates :status, :inclusion => { :in => [STATUS_QUEUED, STATUS_RUNNING, STATUS_ERROR, STATUS_READY] }

    delegate :ext_management_system, :to => :middleware_server
    delegate :ems_id, :to => :middleware_server
    after_create :enqueue_job
    before_create :set_queued_date

    after_initialize do |item|
      item.status = STATUS_QUEUED if new_record?
    end

    def queued?
      status == STATUS_QUEUED
    end

    def ready?
      status == STATUS_READY
    end

    def erred?
      status == STATUS_ERROR
    end

    def ran?
      ready? || erred?
    end

    def generate_diagnostic_report
      $mw_log.debug("#{log_prefix} Sending to Hawkular a request to generate JDR report [#{id}].")

      self.status = STATUS_RUNNING
      save!

      callback = proc do |on|
        on.success(&method(:jdr_report_succeded))
        on.failure(&method(:jdr_report_failed))
      end

      @connection = ext_management_system.connect.operations(true)
      @finish_signal = Queue.new
      @connection.export_jdr(middleware_server.ems_ref, true, &callback)

      Timeout.timeout(::Settings.ems.ems_hawkular.jdr.generation_timeout.to_i_with_method) { @finish_signal.deq }
    rescue Timeout::Error
      self.status = STATUS_ERROR
      self.error_message = _('Reached generation timeout.')
      save!
    rescue => ex
      self.status = STATUS_ERROR
      self.error_message = ex.to_s
      save!
    ensure
      @connection.close_connection! if @connection
    end

    private

    def set_queued_date
      self.queued_at = Time.current if queued?
    end

    def enqueue_job
      unless queued?
        $mw_log.debug("#{log_prefix} JDR report registry [#{id}] for server [#{middleware_server.ems_ref}] created with status [#{status}].")
        return
      end

      job = MiqQueue.submit_job(
        :class_name  => self.class.name,
        :instance_id => id,
        :role        => 'ems_operations',
        :method_name => 'generate_diagnostic_report',
        :msg_timeout => ::Settings.ems.ems_hawkular.jdr.generation_timeout.to_i_with_method + 30.seconds
      )

      EmsEvent.add_queue(
        'add', ems_id,
        :ems_id          => ems_id,
        :source          => 'EVM',
        :timestamp       => Time.zone.now,
        :event_type      => 'hawkular_event',
        :message         => _('Generation of JDR report was requested by a user.'),
        :middleware_ref  => middleware_server.ems_ref,
        :middleware_type => 'MiddlewareServer',
        :username        => requesting_user
      )

      $mw_log.info("#{log_prefix} JDR report [#{id}] for server [#{middleware_server.ems_ref}] enqueued with job #{job.id}.")
    end

    def jdr_report_succeded(data)
      reload
      self.class.transaction do
        if binary_blob
          $mw_log.debug("#{log_prefix} JDR report [#{id}] [#{binary_blob.name}] will be overwritten.")
          binary_blob.name = data['fileName']
          binary_blob.data_type = 'zip'
        else
          self.binary_blob = BinaryBlob.create(:name => data['fileName'], :data_type => 'zip')
        end

        binary_blob.binary = data[:attachments]
        self.status = STATUS_READY
        save!
      end

      $mw_log.info("#{log_prefix} Generation of JDR report [#{id}] [#{binary_blob.name}] succeded.")

      # Unblock main thread at generate_diagnostic_report method
      @finish_signal << :success
    end

    def jdr_report_failed(error)
      $mw_log.warn("#{log_prefix} Generation of JDR report [#{id}] failed: #{error}.")
      self.status = STATUS_ERROR
      self.error_message = error
      save!

      # Unblock main thread at generate_diagnostic_report method
      @finish_signal << :failure
    end

    def log_prefix
      @_log_prefix ||= "EMS_#{ems_id}(Hawkular::MWM::MwDiagnosticReport)"
    end
  end
end
