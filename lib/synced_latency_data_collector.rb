require "synced_latency_data_collector/version"
require "synced_latency_data_collector/configuration"
require "synced_latency_data_collector/datadog_collector"
require "synced_latency_data_collector/datadog_collector_job"
require "synced_latency_data_collector/scheduler"
require "datadog/statsd"

class SyncedLatencyDataCollector
  def self.configuration
    @configuration ||= SyncedLatencyDataCollector::Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.datadog_stats_client
    Datadog::Statsd.new(configuration.datadog_host, configuration.datadog_port)
  end

  def self.collect
    SyncedLatencyDataCollector::DatadogCollector.new(datadog_stats_client, configuration).collect
  end

  def self.schedule!
    SyncedLatencyDataCollector::Scheduler.new(configuration).schedule!
  end
end

