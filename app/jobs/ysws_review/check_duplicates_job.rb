class YswsReview::CheckDuplicatesJob < ApplicationJob
  queue_as :default

  def perform
    records_to_check = source_table.all(
      max_records: 10,
      filter: "BLANK() = {Duplicate?}",
      sort: { "Created at": "asc" }
    )

    return if records_to_check.empty?

    puts "Found #{records_to_check.count} records to check for duplicates"

    records_to_update = []

    records_to_check.each do |record|
      code_url = record.fields["Code URL"]

      unless code_url.present?
        puts "Skipping record #{record.id} - no Code URL"
        next
      end

      duplicate_record = find_duplicate_in_unified_db(code_url)

      if duplicate_record
        puts "Found duplicate for #{code_url}: #{duplicate_record.id}"
        record["Duplicate?"] = duplicate_record.id
      else
        puts "No duplicate found for #{code_url}"
        record["Duplicate?"] = "N/A"
      end

      records_to_update << record
    end

    if records_to_update.any?
      source_table.batch_upsert(records_to_update, "id")
      puts "Successfully updated #{records_to_update.count} records with duplicate status"
    end
  end

  private

  def find_duplicate_in_unified_db(code_url)
    unified_db_table.all(
      filter: "AND({Code URL} = '#{code_url}', NOT({YSWS} = 'Flavortown'))"
    ).first
  end

  def source_table
    @source_table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      "appNF8MGrk5KKcYZx",
      "ysws_submission"
    )
  end

  def unified_db_table
    @unified_db_table ||= Norairrecord.table(
      ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"],
      "app3A5kJwYqxMLOgh",
      "Approved Projects"
    )
  end
end
