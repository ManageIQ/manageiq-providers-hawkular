namespace :spec do
  desc "Setup environment specs"
  task :setup => ["app:test:vmdb:setup"]

  desc 'Run most specs using a real MW Manager and not using recorded cassettes'
  task :live do
    Rake::Task['spec:hawkular:setup'].invoke
    ENV['VCR_RECORD_ALL'] = '1'
    Rake::Task['spec'].invoke
    Rake::Task['spec:hawkular:down'].invoke
  end
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec => ["app:test:initialize", "app:evm:compile_sti_loader"]) do |t|
  spec_dir = File.expand_path("../../spec", __dir__)
  EvmTestHelper.init_rspec_task(t, ['--require', File.join(spec_dir, 'spec_helper')])
end
