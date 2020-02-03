RSpec.describe SyncedLatencyDataCollector::Configuration do
  describe "datadog_host" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.datadog_host = :datadog_host
      }.to change { config.datadog_host }.from(nil).to(:datadog_host)
    end
  end

  describe "datadog_port" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.datadog_port = :datadog_port
      }.to change { config.datadog_port }.from(nil).to(:datadog_port)
    end
  end

  describe "datadog_namespace" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.datadog_namespace = :datadog_namespace
      }.to change { config.datadog_namespace }.from(nil).to(:datadog_namespace)
    end
  end

  describe "active_accounts_scope_proc" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.active_accounts_scope_proc = :active_accounts_scope_proc
      }.to change { config.active_accounts_scope_proc }.from(nil).to(:active_accounts_scope_proc)
    end
  end

  describe "account_model_proc" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.account_model_proc = :account_model_proc
      }.to change { config.account_model_proc }.from(nil).to(:account_model_proc)
    end
  end

  describe "synced_timestamp_model" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.synced_timestamp_model = :synced_timestamp_model
      }.to change { config.synced_timestamp_model }.from(nil).to(:synced_timestamp_model)
    end
  end

  describe "global_models_proc" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.global_models_proc = :global_models_proc
      }.to change { config.global_models_proc }.to(:global_models_proc)
    end

    it "returns a proc that returning an empty array if not set" do
      expect(config.global_models_proc.call).to eq []
    end
  end

  describe "account_scoped_models_proc" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.account_scoped_models_proc = :account_scoped_models_proc
      }.to change { config.account_scoped_models_proc }.to(:account_scoped_models_proc)
    end

    it "returns a proc that returning an empty array if not set" do
      expect(config.global_models_proc.call).to eq []
    end
  end

  describe "non_account_scoped_models_proc" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.non_account_scoped_models_proc = :non_account_scoped_models_proc
      }.to change { config.non_account_scoped_models_proc }.to(:non_account_scoped_models_proc)
    end

    it "returns a proc that returning an empty array if not set" do
      expect(config.global_models_proc.call).to eq []
    end
  end

  describe "active_scope_for_different_parent" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.active_scope_for_different_parent = :active_scope_for_different_parent
      }.to change { config.active_scope_for_different_parent }.from(nil).to(:active_scope_for_different_parent)
    end
  end

  describe "sidekiq_job_queue" do
    subject(:config) { described_class.new }

    it "is an attr accessor" do
      expect {
        config.sidekiq_job_queue = :sidekiq_job_queue
      }.to change { config.sidekiq_job_queue }.from(nil).to(:sidekiq_job_queue)
    end
  end
end
