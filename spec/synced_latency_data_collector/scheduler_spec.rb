require "sidekiq/redis_connection"
require "sidekiq-cron"

RSpec.describe SyncedLatencyDataCollector::Scheduler do
  describe "#schedule!" do
    subject(:schedule!) { described_class.new(configuration).schedule! }

    let(:configuration) do
      SyncedLatencyDataCollector::Configuration.new.tap { |config| config.sidekiq_job_queue = :critical }
    end

    let(:redis_url) { ENV.fetch("REDIS_URL", "redis://localhost:6379") }
    let(:redis_namespace) { "SyncedLatencyDataCollector_Scheduler_test" }

    before do
      Sidekiq.configure_client do |config|
        config.redis = { url:  redis_url, namespace: redis_namespace }
      end
      Sidekiq.redis do |sidekiq_connection|
        sidekiq_connection.redis.flushdb
        sidekiq_connection.keys("cron_job*").each do |key|
          sidekiq_connection.del(key)
        end
      end
    end

    context "when the job already exists" do
      before do
        schedule!
      end

      it "does not add a new job to the schedule" do
        expect {
          schedule!
        }.not_to change { Sidekiq::Cron::Job.count }
      end
    end

    context "when the job does not exist" do
      let(:created_job) { Sidekiq::Cron::Job.find(name: "synced_latency_data_collector") }

      it "adds a new job to the schedule" do
        expect {
          schedule!
        }.to change { Sidekiq::Cron::Job.count }.from(0).to(1)

        expect(created_job.name).to eq "synced_latency_data_collector"
        expect(created_job.cron).to eq "* * * * *"
        expect(created_job.klass).to eq "SyncedLatencyDataCollector::DatadogCollectorJob"
        expect(created_job.queue_name_with_prefix).to eq "critical"
        expect(created_job.is_active_job?).to be_falsey
        expect(created_job.description).to eq "Collect latency metrics from synced"
      end
    end
  end
end
