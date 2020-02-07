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
      global_models_proc.call.each do |model|
        timestamp = synced_timestamp_model
          .where(parent_scope: nil, model_class: model.to_s)
          .order(:synced_at)
          .last

        register_latency_if_timestamp_exists(model, timestamp)
      end
    end

    def collect_for_account_scoped_models
      model_classes = account_scoped_models_proc.call.map(&:to_s)
      models_with_timestamps = fetch_models_with_timestamps_for_parent_and_dependent_models(active_accounts, model_classes)

      models_with_timestamps.each do |model_name, timestamp|
        register_latency_if_timestamp_exists(infer_model_model_class_from_name(model_name), timestamp)
      end
    end

    def collect_for_differently_scoped_models
      parent_models_with_models = group_dependent_models_by_parent_model(non_account_scoped_models_proc.call)
      account_model_name = account_model_proc.call.model_name.singular

      parent_models_with_models.each do |parent_model, dependent_models|
        parent_scope = parent_model.where(account_model_name => active_accounts).public_send(active_scope_for_different_parent)
        model_class = dependent_models.map(&:to_s)
        models_with_timestamps = fetch_models_with_timestamps_for_parent_and_dependent_models(parent_scope, model_class)

        models_with_timestamps.each do |model_name, timestamp|
          register_latency_if_timestamp_exists(infer_model_model_class_from_name(model_name), timestamp)
        end
      end
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

    def infer_model_model_class_from_name(name)
      Object.const_get(name)
    end

    def group_dependent_models_by_parent_model(non_account_scoped_models)
      non_account_scoped_models
        .group_by { |parent, _| parent }
        .map { |parent, group| [parent, group.map { |sub_group| sub_group.last }] }
        .to_h
    end

    def fetch_models_with_timestamps_for_parent_and_dependent_models(parent_scope, model_class)
      synced_timestamp_model
        .select("DISTINCT ON (parent_scope_id, model_class) #{synced_timestamp_table}.synced_at, #{synced_timestamp_table}.model_class")
        .where(parent_scope: parent_scope, model_class: model_class)
        .order(:parent_scope_id, :model_class, synced_at: :desc)
        .group_by(&:model_class)
        .map { |model_name, timestamps| [model_name, timestamps.min_by(&:synced_at)] }
    end
  end
end
