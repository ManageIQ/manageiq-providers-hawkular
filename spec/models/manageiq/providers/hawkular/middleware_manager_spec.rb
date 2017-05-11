describe ManageIQ::Providers::Hawkular::MiddlewareManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('hawkular')
  end

  it ".description" do
    expect(described_class.description).to eq('Hawkular')
  end

  describe "miq_id_prefix" do
    let(:random_id) { SecureRandom.hex(10) }
    let!(:my_region) do
      MiqRegion.my_region || FactoryGirl.create(:miq_region, :region => MiqRegion.my_region_number)
    end
    let(:random_region) do
      region = Random.rand(1..99) while !region || region == my_region.region
      MiqRegion.find_by(:region => region) || FactoryGirl.create(:miq_region, :region => region)
    end

    it "must return non-empty string" do
      rval = subject.miq_id_prefix
      expect(rval.to_s.strip).not_to be_empty
    end

    it "must prefix the provided string/identifier" do
      rval = subject.miq_id_prefix(random_id)

      expect(rval).to end_with(random_id)
      expect(rval).not_to eq(random_id)
    end

    it "must generate different prefixes for different providers" do
      ems_a = FactoryGirl.create(:ems_hawkular)
      ems_b = FactoryGirl.create(:ems_hawkular)

      expect(ems_a.miq_id_prefix).not_to eq(ems_b.miq_id_prefix)
    end

    it "must generate different prefixes for same provider on different MiQ region" do
      ems_a = FactoryGirl.create(:ems_hawkular)
      ems_b = ems_a.dup
      ems_b.id = described_class.id_in_region(ems_a.id % described_class::DEFAULT_RAILS_SEQUENCE_FACTOR, random_region.region)

      expect(ems_a.miq_id_prefix).not_to eq(ems_b.miq_id_prefix)
    end
  end
end
