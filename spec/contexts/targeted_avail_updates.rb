RSpec.shared_context 'targeted_avail_updates' do
  let(:ems_hawkular) { FactoryGirl.create(:ems_hawkular) }
  let(:target) { ::ManageIQ::Providers::Hawkular::Inventory::AvailabilityUpdates.new([]) }
  let(:persister) { ::ManageIQ::Providers::Hawkular::Inventory::Persister::AvailabilityUpdates.new(ems_hawkular, target) }
  let(:collector) { ::ManageIQ::Providers::Hawkular::Inventory::Collector::AvailabilityUpdates.new(ems_hawkular, target) }
  let(:parser) do
    parser = described_class.new
    parser.collector = collector
    parser.persister = persister
    parser
  end
end
