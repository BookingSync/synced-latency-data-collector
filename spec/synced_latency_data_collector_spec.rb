RSpec.describe SyncedLatencyDataCollector do
  it "has a version number" do
    expect(SyncedLatencyDataCollector::VERSION).not_to be nil
  end

  describe ".configure" do
    subject(:configuration) { described_class.configuration }

    around do |example|
      original_datadog_host = configuration.datadog_host
      original_datadog_port = configuration.datadog_port
      original_datadog_namespace = configuration.datadog_namespace
      original_active_accounts_scope_proc = configuration.active_accounts_scope_proc

      SyncedLatencyDataCollector.configure do |config|
        config.datadog_host = :datadog_host
        config.datadog_port = :datadog_port
        config.datadog_namespace = :datadog_namespace
        config.active_accounts_scope_proc = :active_accounts_scope_proc
      end

      example.run

      SyncedLatencyDataCollector.configure do |config|
        config.datadog_host = original_datadog_host
        config.datadog_port = original_datadog_port
        config.datadog_namespace = original_datadog_namespace
        config.active_accounts_scope_proc = original_active_accounts_scope_proc
      end
    end

    it "is configurable" do
      expect(configuration.datadog_host).to eq :datadog_host
      expect(configuration.datadog_port).to eq :datadog_port
      expect(configuration.datadog_namespace).to eq :datadog_namespace
      expect(configuration.active_accounts_scope_proc).to eq :active_accounts_scope_proc
    end
  end

  describe ".datadog_stats_client" do
    subject(:datadog_stats_client) { described_class.datadog_stats_client }

    it { is_expected.to be_instance_of Datadog::Statsd }
  end

  describe ".collect" do
    subject(:collect) { described_class.collect }

    it "calls SyncedLatencyDataCollector::DatadogCollector" do
      expect_any_instance_of(SyncedLatencyDataCollector::DatadogCollector).to receive(:collect)

      collect
    end
  end

  describe ".schedule!" do
    subject(:schedule!) { described_class.schedule! }

    it "calls SyncedLatencyDataCollector::Scheduler" do
      expect_any_instance_of(SyncedLatencyDataCollector::Scheduler).to receive(:schedule!)

      schedule!
    end
  end
end
