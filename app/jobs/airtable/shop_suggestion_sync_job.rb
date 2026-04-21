class Airtable::ShopSuggestionSyncJob < ApplicationJob
  queue_as :literally_whenever

  retry_on Norairrecord::Error, wait: :polynomially_longer, attempts: 3 do |job, error|
    Rails.logger.error("[#{job.class.name}] Failed after retries: #{error.message}")
  end

  def perform(shop_suggestion_id)
    suggestion = ShopSuggestion.find_by(id: shop_suggestion_id)
    return if suggestion.nil?

    table.create(field_mapping(suggestion))
  end

  private

  def field_mapping(suggestion)
    {
      "Item" => suggestion.item.to_s,
      "Link" => suggestion.link.presence,
      "Notes" => suggestion.explanation.to_s,
      "User ID" => suggestion.user&.id&.to_s,
      "Slack ID" => suggestion.user&.slack_id
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
