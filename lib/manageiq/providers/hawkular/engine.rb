module ManageIQ
  module Providers
    module Hawkular
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Hawkular
      end
    end
  end
end
