class Airtable::BaseSyncJob < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    airtable_records = records_to_sync.map do |record|
      table.new(field_mapping(record))
    end

    table.batch_upsert(airtable_records, primary_key_field)
  ensure
    records_to_sync.update_all(synced_at_field => Time.now)
  end

  private

  def table_name
    raise NotImplementedError, "Subclass must implement #table_name"
  end

  def records
    raise NotImplementedError, "Subclass must implement #records"
  end

  def field_mapping(_record)
    raise NotImplementedError, "Subclass must implement #field_mapping"
  end

  def synced_at_field
    :synced_at
  end

  def primary_key_field
    "flavor_id"
  end

  def sync_limit
    10
  end

  def records_to_sync
    @records_to_sync ||= records.order("#{synced_at_field} ASC NULLS FIRST").limit(sync_limit)
  end

  def table
    @table ||= Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      table_name
    )
  end
end
