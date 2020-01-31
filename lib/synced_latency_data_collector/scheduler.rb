class SyncedLatencyDataCollector
  class Scheduler
    JOB_NAME = "synced_latency_data_collector".freeze
    EVERY_MINUTE_IN_CRON_SYNTAX = "* * * * *".freeze
    JOB_CLASS_NAME = "SyncedLatencyDataCollector::DatadogCollectorJob".freeze
    JOB_DESCRIPTION = "Collect latency metrics from synced".freeze

    private_constant :JOB_NAME, :EVERY_MINUTE_IN_CRON_SYNTAX, :JOB_CLASS_NAME, :JOB_DESCRIPTION

    attr_reader :configuration
    private     :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def schedule!
      find || create
    end

    private

    def find
      Sidekiq::Cron::Job.find(name: JOB_NAME)
    end

    def create
      Sidekiq::Cron::Job.create(create_job_arguments)
    end

    def create_job_arguments
      {
        name: JOB_NAME,
        cron: EVERY_MINUTE_IN_CRON_SYNTAX,
        class: "SyncedLatencyDataCollector::DatadogCollectorJob",
        queue: configuration.sidekiq_job_queue,
        active_job: false,
        description: JOB_DESCRIPTION
      }
    end

    def every_minute_to_cron_syntax
      EVERY_MINUTE_IN_CRON_SYNTAX
    end
  end
end
