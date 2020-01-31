RSpec.describe SyncedLatencyDataCollector::DatadogCollectorJob do
  describe "#perform" do
    subject(:perform) { described_class.new.perform }

    it "calls SyncedLatencyDataCollector.collect" do
      expect(SyncedLatencyDataCollector).to receive(:collect)

      perform
    end
  end
end
