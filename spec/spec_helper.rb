if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Hawkular::Engine.root, 'spec/vcr_cassettes')
  config.default_cassette_options = { :record => :new_episodes } if ENV['VCR_RECORD_NEW']
  config.default_cassette_options = { :record => :all } if ENV['VCR_RECORD_ALL']
end

if ENV['VCR_OFF']
  VCR.turn_off!(:ignore_cassettes => true)
  WebMock.allow_net_connect!
end

require 'contexts/targeted_avail_updates'

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[ManageIQ::Providers::Hawkular::Engine.root.join("spec/support/**/*.rb")].each { |f| require f }
