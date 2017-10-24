require 'net/http'
require 'json'
require 'hawkularclient'

module ManageIQ::Providers::Hawkular::TaskHelpers
  class LiveSetup
    CI_FILES_PATH = File.expand_path('../../ci_files/', __dir__).freeze
    DOCKERFILE_WF_STANDALONE = File.expand_path('./Dockerfile-wf-standalone', CI_FILES_PATH).freeze
    COMPOSE_FILE = File.expand_path('./docker-compose.yml', CI_FILES_PATH).freeze

    def self.hawkular_client
      ::Hawkular::Client.new(:entrypoint  => 'http://localhost:8080',
                             :credentials => {:username => 'jdoe', :password => 'password'},
                             :options     => {:tenant => 'hawkular'})
    end

    def self.wait_until_ready(collection)
      raise 'Block required to test readiness.' unless block_given?

      collection.each do |item|
        print "* #{item} ... waiting\r"
        is_ready = false
        until is_ready
          is_ready = yield(item)
          sleep(1)
        end

        puts "\033[2K* #{item} ... READY"
      end
    end

    def self.check_docker
      print "Checking for Docker and Compose... "

      system('docker version > /dev/null') || (
        raise 'Docker is not available. Please, be sure it is installed and running.')
      system('docker-compose version > /dev/null') || (
        raise 'Docker Compose is not available. Please, be sure it is installed.')

      puts 'ok.'
    end

    def self.build_custom_wildfly_standalone
      print "Building customized docker image for Wildfly standalone... "
      system("docker build -f #{DOCKERFILE_WF_STANDALONE} -t manageiq/wf-standalone #{CI_FILES_PATH} > /dev/null") || (
        raise 'Failed to build customized docker image for Wildfly standalone.')
      puts "done."
    end

    def self.start_mw_manager
      print "Starting Cassandra and MW Manager... "
      system("docker-compose -f #{COMPOSE_FILE} up -d cassandra hawkular 2> /dev/null > /dev/null")
      puts "done."

      puts "Waiting for MW Manager to be ready... "

      test_endpoints = {
        'H-services' => {
          :uri  => 'http://localhost:8080/hawkular/status',
          :test => ->(h) { h['Implementation-Version'] }
        },
        'H-alerts'   => {
          :uri  => 'http://localhost:8080/hawkular/alerts/status',
          :test => ->(h) { h['status'] == 'STARTED' }
        },
        'H-metrics'  => {
          :uri  => 'http://localhost:8080/hawkular/metrics/status',
          :test => ->(h) { h['MetricsService'] == 'STARTED' }
        }
      }

      wait_until_ready(['H-services', 'H-alerts', 'H-metrics']) do |endpoint|
        endpoint = test_endpoints[endpoint]
        begin
          response = JSON.parse(Net::HTTP.get(URI(endpoint[:uri])))
          endpoint[:test].call(response)
        rescue
          false
        end
      end

      puts 'MW Manager is ready.'
    end

    def self.start_wildflies
      print "Starting one standalone and one domain WF servers... "
      system("docker-compose -f #{COMPOSE_FILE} up -d wildfly-standalone wildfly-domain 2> /dev/null > /dev/null")
      puts "done."

      puts "Waiting for feeds to be in inventory..."
      feeds_to_test = ['mw-manager', 'wf-standalone', 'master.Unnamed Domain']

      client = hawkular_client.inventory
      wait_until_ready(feeds_to_test) { |feed| client.list_feeds.find { |f| f == feed } }
    end

    def self.wait_for_metrics_data
      puts 'Waiting for some metrics to be pushed...'

      metrics_to_test = [
        'MI~R~[wf-standalone/Local DMR~~]~MT~WildFly Memory Metrics~NonHeap Used',
        'MI~R~[mw-manager/Local~~]~MT~WildFly Memory Metrics~Heap Committed',
        'MI~R~[mw-manager/Local~/subsystem=messaging-activemq/server=default/jms-queue=DLQ]~MT~JMS Queue Metrics~Scheduled Count',
        'MI~R~[mw-manager/Local~/subsystem=messaging-activemq/server=default/jms-topic=HawkularAlertData]~MT~JMS Topic Metrics~Message Count',
        'MI~R~[master.Unnamed Domain/Local~/host=master/server=server-one]~MT~WildFly Memory Metrics~Heap Used',
        'MI~R~[wf-standalone/Local DMR~/subsystem=datasources/data-source=ExampleDS]~MT~Datasource Pool Metrics~In Use Count',
        'MI~R~[wf-standalone/Local DMR~/subsystem=datasources/data-source=ExampleDS]~MT~Datasource Pool Metrics~Max Wait Time'
      ]

      client = hawkular_client.metrics.gauges
      wait_until_ready(metrics_to_test) { |metric_id| client.get_data(metric_id).count >= 2 }
    end
  end
end

namespace(:spec) do
  namespace(:hawkular) do
    desc('Uses Docker to start MW Manager and attaches one standalone and one domain WF servers')
    task(:setup) do
      helpers = ManageIQ::Providers::Hawkular::TaskHelpers::LiveSetup
      helpers.check_docker
      helpers.build_custom_wildfly_standalone
      helpers.start_mw_manager
      helpers.start_wildflies
      helpers.wait_for_metrics_data

      puts "All set. Ready to run tests with real MW Manager."
    end

    desc('Stops and deletes docker containers created by task spec:hawkular:setup')
    task(:down) do
      compose_file = ManageIQ::Providers::Hawkular::TaskHelpers::LiveSetup::COMPOSE_FILE
      system("docker-compose -f #{compose_file} down")
    end
  end
end
