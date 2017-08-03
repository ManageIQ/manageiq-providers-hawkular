require_relative 'hawkular_helper'

describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareJdrReport do
  subject(:report) { FactoryGirl.build(:hawkular_jdr_report) }
  before(:context) do
    MiqServer.seed
  end

  it 'assigns queued status for new instances' do
    expect(described_class.new.status).to be == described_class::STATUS_QUEUED
  end

  it 'registers an item in miq queue for new reports with queued status' do
    report.save!

    queue_item = MiqQueue.find_by(
      :method_name => 'generate_jdr_report',
      :class_name  => described_class.name,
      :instance_id => report.id
    )

    expect(queue_item).to_not be_blank
    expect(report.queued_at).to_not be_blank
  end

  it 'validates presence of requesting user field' do
    report.requesting_user = ''
    expect(report.valid?).to be_falsey
  end

  it 'validates association to a middleware server' do
    report.middleware_server = nil
    expect(report.valid?).to be_falsey
  end

  it 'rejects a not allowed status' do
    report.status = 'foo'
    expect(report.valid?).to be_falsey
  end

  it 'has ran when report is in ready or error state' do
    report.status = described_class::STATUS_READY
    expect(report.ran?).to be_truthy

    report.status = described_class::STATUS_ERROR
    expect(report.ran?).to be_truthy
  end

  it 'has not ran when report is in queued or running state' do
    report.status = described_class::STATUS_QUEUED
    expect(report.ran?).to be_falsey

    report.status = described_class::STATUS_RUNNING
    expect(report.ran?).to be_falsey
  end

  describe '#generate_jdr_report' do
    let(:ems) do
      ems = ems_hawkular_fixture
      allow(ems).to receive(:connect).and_return(hawkular_client_stub)
      ems
    end
    let(:mw_server) do
      FactoryGirl.create(
        :hawkular_middleware_server,
        :ext_management_system => ems,
        :ems_ref               => 'hawk_ref'
      )
    end
    let(:hawkular_operations_client_stub) do
      client = instance_double('::Hawkular::Operations::Client')
      allow(client).to receive(:export_jdr)
      allow(client).to receive(:close_connection!)
      client
    end
    let(:hawkular_client_stub) do
      client = instance_double('::Hawkular::Client')
      allow(client).to receive(:operations).and_return(hawkular_operations_client_stub)
      client
    end

    subject(:report) do
      report = FactoryGirl.create(:hawkular_jdr_report, :middleware_server => mw_server)
      report.middleware_server.ext_management_system = ems
      report
    end

    it 'should invoke report generation to Hawkular client and assign running status' do
      expect(hawkular_operations_client_stub).to receive(:export_jdr).with('hawk_ref', true) do
        report.instance_variable_get('@finish_signal') << 1
      end

      report.generate_jdr_report
      expect(report.status).to be == described_class::STATUS_RUNNING
    end

    it 'should assign ready status and save report if jdr generation succeeds' do
      expect(hawkular_operations_client_stub).to receive(:export_jdr).with('hawk_ref', true) do |&blk|
        blk.perform(:success, 'fileName' => 'jdr_report', :attachments => 'jdr_report_data')
      end

      report.generate_jdr_report
      expect(report.status).to be == described_class::STATUS_READY
      expect(report.binary_blob).to_not be_blank
      expect(report.binary_blob.binary).to be == 'jdr_report_data'
    end

    it 'should assign error status and save error message if jdr generation fails' do
      expect(hawkular_operations_client_stub).to receive(:export_jdr).with('hawk_ref', true) do |&blk|
        blk.perform(:failure, 'jdr_report_error')
      end

      report.generate_jdr_report
      expect(report.status).to be == described_class::STATUS_ERROR
      expect(report.error_message).to be == 'jdr_report_error'
    end

    it 'should assign error status and save message if jdr generation timeouts' do
      ::Settings.ems.ems_hawkular.jdr.generation_timeout = '1.second'

      report.generate_jdr_report
      expect(report.status).to be == described_class::STATUS_ERROR
      expect(report.error_message).to be == _('Reached generation timeout.')
    end
  end
end
