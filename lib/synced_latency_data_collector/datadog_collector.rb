require "forwardable"

class SyncedLatencyDataCollector
  class DatadogCollector
    extend Forwardable

    attr_reader :datadog_statsd_client, :configuration
    private     :datadog_statsd_client, :configuration

    METRIC_NAME_PREFIX = "synced".freeze
    METRIC_NAME_SUFFIX = "maximum_sync_latency_in_minutes".freeze
    METRIC_NAME_SEPARATOR = ".".freeze
    private_constant :METRIC_NAME_PREFIX, :METRIC_NAME_SUFFIX, :METRIC_NAME_SEPARATOR

    def_delegators :configuration, :active_accounts_scope_proc, :datadog_namespace,
      :synced_timestamp_model, :global_models_proc, :account_scoped_models_proc, :account_model_proc,
      :non_account_scoped_models_proc, :active_scope_for_different_parent

    def initialize(datadog_statsd_client, configuration)
      @datadog_statsd_client = datadog_statsd_client
      @configuration = configuration
    end

    def collect
      collect_for_global_models
      collect_for_account_scoped_models
      collect_for_differently_scoped_models
    end

    private

    def collect_for_global_models
      global_models_proc.call.map do |model|
        Thread.new do
          timestamp = nil
          with_connection_pool do
            timestamp = synced_timestamp_model
              .where(parent_scope: nil, model_class: model.to_s)
              .order(:synced_at)
              .last
          end

          register_latency_if_timestamp_exists(model, timestamp)
        end
      end.map(&:join)
    end

    def collect_for_account_scoped_models
      account_scoped_models_proc.call.map do |model|
        Thread.new do
          timestamp = nil
          with_connection_pool do
            timestamp = synced_timestamp_model
              .select("DISTINCT ON (parent_scope_id) #{synced_timestamp_table}.synced_at")
              .where(parent_scope: active_accounts, model_class: model.to_s)
              .order(:parent_scope_id, synced_at: :desc)
              .min_by(&:synced_at)
          end

          register_latency_if_timestamp_exists(model, timestamp)
        end
      end.map(&:join)
    end

    def collect_for_differently_scoped_models
      non_account_scoped_models_proc.call.map do |parent_model, model|
        account_model_name = account_model_proc.call.model_name.singular
        Thread.new do
          timestamp = nil
          with_connection_pool do
            timestamp = synced_timestamp_model
              .select("DISTINCT ON (parent_scope_id) #{synced_timestamp_table}.synced_at")
              .where(parent_scope: parent_model.where(account_model_name => active_accounts).public_send(active_scope_for_different_parent),
                model_class: model.to_s)
              .order(:parent_scope_id, synced_at: :desc)
              .min_by(&:synced_at)
          end

          register_latency_if_timestamp_exists(model, timestamp)
        end
      end.map(&:join)
    end

    def register_latency_if_timestamp_exists(model, timestamp)
      register_latency(model, calculate_latency(timestamp)) if timestamp
    end

    def register_latency(model_klass, latency_in_minutes)
      datadog_statsd_client.count(build_metric_name(model_klass), latency_in_minutes)
    end

    def calculate_latency(timestamp)
      latency_in_seconds = Time.current - timestamp.synced_at
      (latency_in_seconds / 60).floor
    end

    def active_accounts
      @active_accounts ||= active_accounts_scope_proc.call
    end

    def build_metric_name(model_klass)
      [
        METRIC_NAME_PREFIX,
        datadog_namespace,
        model_klass.model_name.param_key,
        METRIC_NAME_SUFFIX
      ].join(METRIC_NAME_SEPARATOR)
    end

    def synced_timestamp_table
      @synced_timestamp_table ||= synced_timestamp_model.table_name
    end

    def with_connection_pool
      ActiveRecord::Base.connection_pool.with_connection do
        yield
      end
    end
  end
end
