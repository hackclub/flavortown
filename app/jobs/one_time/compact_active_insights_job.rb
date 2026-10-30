class OneTime::CompactActiveInsightsJob < ApplicationJob
  queue_as :literally_whenever

  # Run once before PruneActiveInsightsJob starts on a large table: deleting
  # tens of millions of rows in batches would take hours, flood the WAL and
  # still leave the disk space allocated. This keeps the retention window by
  # copying it aside, truncating, and copying it back.
  def perform
    cutoff = PruneActiveInsightsJob::RETENTION.ago

    [ ActiveInsights::Request, ActiveInsights::Job ].each do |model|
      connection = model.connection
      table = model.quoted_table_name
      columns = model.columns.reject(&:virtual?).map { |c| connection.quote_column_name(c.name) }.join(", ")

      model.transaction do
        connection.execute("CREATE TEMP TABLE kept_insights ON COMMIT DROP AS SELECT #{columns} FROM #{table} WHERE started_at >= #{connection.quote(cutoff)}")
        connection.execute("TRUNCATE #{table}")
        connection.execute("INSERT INTO #{table} (#{columns}) SELECT #{columns} FROM kept_insights")
      end
    end
  end
end
