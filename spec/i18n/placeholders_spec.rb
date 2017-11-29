describe :placeholders do
  include_examples :placeholders, ManageIQ::Providers::Hawkular::Engine.root.join('locale').to_s
end
