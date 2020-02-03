RSpec.describe SyncedLatencyDataCollector::DatadogCollector, :freeze_time do
  let(:database_name) { "synced_latency_data_colletor_test" }

  before do
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end

    class Synced
    end

    class Synced::Timestamp < ApplicationRecord
      self.table_name = "synced_timestamps"

      belongs_to :parent_scope, polymorphic: true
    end

    class Bedroom < ApplicationRecord
      belongs_to :rental
    end

    class Bathroom < ApplicationRecord
      belongs_to :rental
    end

    class Rental < ApplicationRecord
      scope :visible, -> { where(canceled_at: nil) }

      belongs_to :account
    end

    class Booking < ApplicationRecord
      belongs_to :account
    end

    class Photo < ApplicationRecord
      belongs_to :account
    end

    class Amenity < ApplicationRecord
    end

    class Account < ApplicationRecord
      scope :active, -> { where(active: true) }
    end

    begin
      ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URI", "postgresql://localhost"))
        .connection
        .drop_database(database_name)
    rescue ActiveRecord::StatementInvalid
    end

    begin
      ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URI", "postgresql://localhost"))
        .connection
        .create_database(database_name)
    rescue ActiveRecord::StatementInvalid
    end
    ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URI", "postgresql://localhost/#{database_name}"))

    class CreateAccounts < ActiveRecord::Migration[4.2]
      def up
        create_table :accounts

        add_column :accounts, :active, :boolean
      end
    end
    CreateAccounts.new.up if !ActiveRecord::Base.connection.table_exists?("accounts")

    class CreateAmenities < ActiveRecord::Migration[4.2]
      def up
        create_table :amenities
      end
    end
    CreateAmenities.new.up if !ActiveRecord::Base.connection.table_exists?("amenities")

    class CreateRentals < ActiveRecord::Migration[4.2]
      def up
        create_table :rentals

        add_column :rentals, :canceled_at, :datetime
        add_column :rentals, :account_id, :integer
      end
    end
    CreateRentals.new.up if !ActiveRecord::Base.connection.table_exists?("rentals")

    class CreateBookings < ActiveRecord::Migration[4.2]
      def up
        create_table :bookings

        add_column :bookings, :account_id, :integer
      end
    end
    CreateBookings.new.up if !ActiveRecord::Base.connection.table_exists?("bookings")

    class CreatePhotos < ActiveRecord::Migration[4.2]
      def up
        create_table :photos

        add_column :photos, :account_id, :integer
      end
    end
    CreatePhotos.new.up if !ActiveRecord::Base.connection.table_exists?("photos")

    class CreateBedrooms < ActiveRecord::Migration[4.2]
      def up
        create_table :bedrooms

        add_column :bedrooms, :rental_id, :integer
      end
    end
    CreateBedrooms.new.up if !ActiveRecord::Base.connection.table_exists?("bedrooms")

    class CreateBathrooms < ActiveRecord::Migration[4.2]
      def up
        create_table :bathrooms

        add_column :bathrooms, :rental_id, :integer
      end
    end
    CreateBathrooms.new.up if !ActiveRecord::Base.connection.table_exists?("bathrooms")

    class CreateSyncedTimestamps < ActiveRecord::Migration[4.2]
      def up
        create_table :synced_timestamps

        add_column :synced_timestamps, :synced_at, :datetime
        add_column :synced_timestamps, :model_class, :string
        add_column :synced_timestamps, :parent_scope_type, :string
        add_column :synced_timestamps, :parent_scope_id, :integer
      end
    end
    CreateSyncedTimestamps.new.up if !ActiveRecord::Base.connection.table_exists?("synced_timestamps")

    Rental.delete_all
    Booking.delete_all
    Bathroom.delete_all
    Bedroom.delete_all
    Photo.delete_all
    Amenity.delete_all
    Account.delete_all
    Synced::Timestamp.delete_all
  end

  describe "#collect" do
    subject(:collect) do
      SyncedLatencyDataCollector::DatadogCollector.new(datadog_statsd_client, configuration).collect
    end

    let(:datadog_statsd_client) do
      Class.new do
        attr_reader :registry

        def initialize
          @registry = []
        end

        def count(name, value)
          @registry << { name => value }
        end
      end.new
    end
    let(:configuration) do
      SyncedLatencyDataCollector::Configuration.new.tap do |config|
        config.active_accounts_scope_proc = active_accounts_scope_proc
        config.datadog_namespace = "example_app.test"
        config.synced_timestamp_model = Synced::Timestamp
        config.global_models_proc = global_models_proc
        config.account_scoped_models_proc = account_scoped_models_proc
        config.non_account_scoped_models_proc = non_account_scoped_models_proc
        config.active_scope_for_different_parent = :visible
      end
    end
    let(:active_accounts_scope_proc) { -> { Account.active } }
    let(:global_models_proc) { -> { [] } }
    let(:account_scoped_models_proc) { -> { [] } }
    let(:non_account_scoped_models_proc) { -> { [] } }

    context "global models (without a scope)" do
      before do
        Synced::Timestamp.create!(synced_at: 1000.seconds.ago, model_class: "Amenity", parent_scope: nil)
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Amenity", parent_scope: nil)
        Synced::Timestamp.create!(synced_at: 610.seconds.ago, model_class: "Amenity", parent_scope: nil)
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Rental", parent_scope_id: 1,
          parent_scope_type: "Account")
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Beedroom", parent_scope_id: 1,
          parent_scope_type: "Rental")
      end

      context "when there is some Synced::Timestamp record" do
        let(:global_models_proc) { -> { [Amenity] } }

        it "collects data for global models based on the maximum applicable latency" do
          expect {
            collect
          }.to change { datadog_statsd_client.registry }.from([]).to([
            { "synced.example_app.test.amenity.maximum_sync_latency_in_minutes" => 5 }
          ])
        end
      end

      context "when there are no any Synced::Timestamp records of that kind" do
        let(:global_models_proc) { -> { [] } }

        it "does not collect anything for these models" do
          expect {
            collect
          }.not_to change { datadog_statsd_client.registry }
        end
      end
    end

    context "account-scoped models" do
      let(:account_scoped_models_proc) { -> { [Rental, Booking] } }
      let!(:account) { Account.create!(active: active) }
      let!(:other_account) { Account.create!(active: active) }

      before do
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Amenity", parent_scope: nil)
        Synced::Timestamp.create!(synced_at: 510.seconds.ago, model_class: "Rental", parent_scope: other_account)
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Rental", parent_scope: account)
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Booking", parent_scope: account)
        Synced::Timestamp.create!(synced_at: 610.seconds.ago, model_class: "Rental", parent_scope: other_account)
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bedroom", parent_scope_id: 1,
          parent_scope_type: "Rental")
      end

      context "when there are some Synced::Timestamp records for active accounts" do
        let(:active) { true }

        # 510/60, because this account has highest latency for rentals
        it "collects data for these models based on the maximum applicable latency" do
          expect {
            collect
          }.to change { datadog_statsd_client.registry }.from([]).to([
            { "synced.example_app.test.rental.maximum_sync_latency_in_minutes" => 8 },
            { "synced.example_app.test.booking.maximum_sync_latency_in_minutes" => 5 }
          ])
        end
      end

      context "when there are no any Synced::Timestamp records of that kind" do
        let(:active) { false }

        it "does not collect anything for these models" do
          expect {
            collect
          }.not_to change { datadog_statsd_client.registry }
        end
      end
    end

    context "non-account-scoped models (with a scope but that is not an account)" do
      let(:non_account_scoped_models_proc) { -> { [[Rental, Bedroom], [Rental, Bathroom], [Rental, Photo]] } }
      let!(:active_account) { Account.create!(active: true) }
      let!(:other_active_account) { Account.create!(active: true) }
      let!(:inactive_account) { Account.create!(active: false) }
      let!(:visible_rental_active_account) { Rental.create!(account: active_account) }
      let!(:visible_rental_2_active_account) { Rental.create!(account: active_account) }
      let!(:visible_rental_other_active_account) { Rental.create!(account: other_active_account) }
      let!(:visible_rental_inactive_account) { Rental.create!(account: inactive_account) }
      let!(:canceled_rental_active_account) { Rental.create!(account: active_account, canceled_at: 1.week.ago) }
      let!(:canceled_rental_inactive_account) { Rental.create!(account: inactive_account, canceled_at: 1.week.ago) }

      context "when there are some Synced::Timestamp records for active accounts for records for scoped parent" do
        before do
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Amenity", parent_scope: nil)
          Synced::Timestamp.create!(synced_at: 510.seconds.ago, model_class: "Rental", parent_scope: active_account)
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bedroom", parent_scope: visible_rental_active_account)
          Synced::Timestamp.create!(synced_at: 410.seconds.ago, model_class: "Bedroom", parent_scope: visible_rental_2_active_account)
          Synced::Timestamp.create!(synced_at: 810.seconds.ago, model_class: "Bedroom", parent_scope: visible_rental_other_active_account)
          Synced::Timestamp.create!(synced_at: 710.seconds.ago, model_class: "Bedroom", parent_scope: visible_rental_other_active_account)
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bedroom", parent_scope: visible_rental_inactive_account)
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bedroom", parent_scope: canceled_rental_active_account)
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bedroom", parent_scope: canceled_rental_inactive_account)
          Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Bathroom", parent_scope: visible_rental_active_account)
        end

        # 710/60, because this rental has highest latency from active accounts for bedrooms
        it "collects data for these models based on the maximum applicable latency" do
          expect {
            collect
          }.to change { datadog_statsd_client.registry }.from([]).to([
            { "synced.example_app.test.bedroom.maximum_sync_latency_in_minutes" => 11 },
            { "synced.example_app.test.bathroom.maximum_sync_latency_in_minutes" => 5 }
          ])
        end
      end

      context "when there are no any Synced::Timestamp records of that kind" do
        it "does not collect anything for these models" do
          expect {
            collect
          }.not_to change { datadog_statsd_client.registry }
        end
      end
    end

    context "complete example" do
      let(:global_models_proc) { -> { [Amenity, Account] } }
      let(:account_scoped_models_proc) { -> { [Rental, Booking] } }
      let(:non_account_scoped_models_proc) { -> { [[Rental, Bedroom], [Rental, Bathroom]] } }
      let!(:rental) { Rental.create!(account: account) }
      let!(:bedroom) { Bedroom.create!(rental: rental) }
      let!(:account) { Account.create!(active: true) }

      before do
        Synced::Timestamp.create!(synced_at: 310.seconds.ago, model_class: "Amenity", parent_scope: nil)
        Synced::Timestamp.create!(synced_at: 210.seconds.ago, model_class: "Rental", parent_scope: account)
        Synced::Timestamp.create!(synced_at: 110.seconds.ago, model_class: "Bedroom", parent_scope: rental)
        Synced::Timestamp.create!(synced_at: 110.seconds.ago, model_class: "Rate", parent_scope: rental)
      end

      it "collects all the stats" do
        expect {
          collect
        }.to change { datadog_statsd_client.registry }.from([]).to([
          { "synced.example_app.test.amenity.maximum_sync_latency_in_minutes" => 5 },
          { "synced.example_app.test.rental.maximum_sync_latency_in_minutes" => 3 },
          { "synced.example_app.test.bedroom.maximum_sync_latency_in_minutes" => 1 }
        ])
      end
    end
  end
end
