require "sidekiq"

class SyncedLatencyDataCollector
  class DatadogCollectorJob

    include Sidekiq::Worker

    def perform
      SyncedLatencyDataCollector.collect
    end
  end
end
