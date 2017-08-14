$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/hawkular/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-hawkular"
  s.version     = ManageIQ::Providers::Hawkular::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-providers-hawkular"
  s.summary     = "Hawkular Provider for ManageIQ"
  s.description = "Hawkular Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,config,lib}/**/*"]

  s.add_runtime_dependency "hawkular-client", "~> 4.1"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end
