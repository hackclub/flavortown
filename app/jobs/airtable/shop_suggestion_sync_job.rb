class Airtable::ShopSuggestionSyncJob < ApplicationJob
  queue_as :literally_whenever

  retry_on Norairrecord::Error, wait: :polynomially_longer, attempts: 3 do |job, error|
    Rails.logger.error("[#{job.class.name}] Failed after retries: #{error.message}")
  end

  def perform(shop_suggestion_id)
    suggestion = ShopSuggestion.find_by(id: shop_suggestion_id)
    return if suggestion.nil?

    table.upsert(field_mapping(suggestion), "ID")
  end

  private

  def field_mapping(suggestion)
    {
      "ID" => SecureRandom.uuid,
      "Item" => suggestion.item.to_s,
      "Link" => suggestion.link.presence,
      "Notes" => suggestion.explanation.to_s
    }
  end

  def table
    @table ||= Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "Shop Suggestions"
    )
  end
end
