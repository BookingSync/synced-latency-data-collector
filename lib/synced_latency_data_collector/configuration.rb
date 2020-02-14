class SyncedLatencyDataCollector::Configuration
  THREE_DAYS_AGO_PROC = -> { Time.now.utc - (3 * 86_400) }

  attr_accessor :datadog_host, :datadog_port, :datadog_namespace, :active_accounts_scope_proc, :account_model_proc,
    :synced_timestamp_model, :global_models_proc, :account_scoped_models_proc, :check_timestamps_since_proc,
    :non_account_scoped_models_proc, :active_scope_for_different_parent, :sidekiq_job_queue

  def global_models_proc
    @global_models_proc || -> { [] }
  end

  def account_scoped_models_proc
    @account_scoped_models_proc || -> { [] }
  end

  def non_account_scoped_models_proc
    @non_account_scoped_models_proc || -> { [] }
  end

  def check_timestamps_since_proc
    @check_timestamps_since_proc || THREE_DAYS_AGO_PROC
  end
end
