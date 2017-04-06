Vmdb::Gettext::Domains.add_domain(
  'ManageIQ_Providers_Hawkular',
  ManageIQ::Providers::Hawkular::Engine.root.join('locale').to_s,
  :po
)
