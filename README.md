# Synced::Latency::Data::Collector

A gem for collecting metrics about synchronization latency.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "synced-latency-data-collector"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install synced-latency-data-collector

## Usage

Add this into an initializer in the Rails app:

``` rb
Rails.application.config.to_prepare do
  SyncedLatencyDataCollector.configure do |config|
    config.datadog_host = ENV.fetch("SYNCED_DATADOG_HOST")
    config.datadog_port = ENV.fetch("SYNCED_DATADOG_PORT")
    config.datadog_namespace = ENV.fetch("SYNCED_DATADOG_NAMESPACE")
    config.active_accounts_scope_proc = -> { Account.active }
    config.account_model_proc = -> { Account } 
    config.synced_timestamp_model = Synced::Timestamp
    config.global_models_proc = -> { [Amenity] }
    config.account_scoped_models_proc =  -> { [Booking, BookingComment, BookingsFee, BookingsTag, Client, Payment, Photo,
      PreferencesGeneralSetting, Rental, RentalsAmenity, RentalsTag, Review, Source]
    }
    config.non_account_scoped_models_proc = -> { [[Rental, Bedroom], [Rental, Bathroom]] }
    config.active_scope_for_different_parent = :visible
    config.sidekiq_job_queue = :critical
  end
end
```

An explanation of the attributes:

* datadog_host - most likely "chef-prod.bookingsync.it"

* datadog_port - most likely 8125

* datadog_namespace - the name of the application and the environment, e.g. "bsa_notifications.production"

* active_accounts_scope_proc - since we want to reject synced timestamps that are created for suspended/canceled accounts and models belonging to these accounts, we need to specify the scope of the applicable accounts for which we want to collect data

* account_model_proc - in some cases, the account model might not be literally the Account one. In majority of the cases, this is going to be `-> { Account }`, however, in some cases it will be something different, e.g. `-> { Website }`.

* synced_timestamp_model - the name of the synced timestamp model, most likely Synced::Timestamp

* global_models_proc - the proc returning an array of models that are not scoped by any model

* account_scoped_models_proc - the proc returning an array of models that are scoped by Account

* non_account_scoped_models_proc - the proc returning an array of models that are not scoped by Account, e.g. by a Rental. Notice that the elements of this array are arrays of two models - a parent and the model for which we are tracking the latency.

* active_scope_for_different_parent - the name of the scope that will be applied when searching for valid synced timestamps related to the models specified in `non_account_scoped_models_proc`. A specific example would be tracking latency for bedrooms' sync belonging only to visible rentals.

* sidekiq_job_queue - the name of the queue for the Sidekiq job


Also, add the job to the schedule that will be run every minute. It's recommended to run this from console rather than using an initializer:

``` rb
SyncedLatencyDataCollector.schedule!
```

That method will add the job to the schedule only if it's not already there yet.

The metrics will be available when creating a new notebook on Datadog.

Also, make sure that you have the following index for synced timestamps:

``` rb
class AddIndexOnModelClassAndSyncedAtForSyncedTimestamps < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :synced_timestamps, [:parent_scope_id, :parent_scope_type, :model_class, :synced_at],
              name: "synced_timestamps_full_index",
              algorithm: :concurrently
  end
end

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/synced-latency-data-collector.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
