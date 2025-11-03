# db/seeds/seeds_shop.rb
# Usage:
# 1) place your CSV at db/seeds/shop_items_export.csv
# 2) run: rails runner db/seeds/shop.rb
#
# This will find_or_initialize_by(id) and update attributes.
require 'csv'
require 'json'
require 'bigdecimal'
require 'bigdecimal/util'

CSV_PATH = Rails.root.join('db', 'seeds', 'shop_items.csv')

puts "Loading shop items from #{CSV_PATH}..."
unless File.exist?(CSV_PATH)
  abort "CSV not found at #{CSV_PATH}. Place the exported CSV there and run again."
end

# converters
parse_bool = ->(v) {
  return nil if v.nil? || v == ''
  s = v.to_s.strip.downcase
  [ 't', 'true', '1', 'yes' ].include?(s)
}

parse_int = ->(v) {
  return nil if v.nil? || v == ''
  begin
    Integer(v)
  rescue
    nil
  end
}

parse_decimal = ->(v) {
  return nil if v.nil? || v == ''
  begin
    # prefer BigDecimal for money-like fields
    BigDecimal(v.to_s)
  rescue
    begin
      Float(v)
    rescue
      nil
    end
  end
}

# Attempt to parse possible JSON-ish content. Many CSV cells contain embedded JSON strings.
parse_json_like = ->(v) {
  return nil if v.nil? || v == ''
  s = v.to_s.strip

  # Some entries have repeated quotes like """""", treat as empty
  return nil if s.gsub('"', '') == ''

  # Try raw JSON parse first
  begin
    JSON.parse(s)
  rescue JSON::ParserError
    # Heuristics: replace doubled quotes with quotes then try
    attempt = s.gsub('""', '"')
    begin
      JSON.parse(attempt)
    rescue JSON::ParserError
      # If it looks like Ruby-ish or bracket content, try eval safely
      if attempt.start_with?('[') || attempt.start_with?('{')
        begin
          # last resort: safe-ish eval via JSON if possible
          # Replace single quotes with double quotes then parse
          attempt2 = attempt.gsub("'", '"')
          JSON.parse(attempt2)
        rescue
          # give up — return raw string
          s
        end
      else
        s
      end
    end
  end
}

# Map CSV -> model attribute conversions
CSV.foreach(CSV_PATH, headers: true) do |row|
  # build attrs hash; convert keys to symbols
  raw = row.to_h

  attrs = {}

  # Basic numeric / string fields
  attrs[:id] = parse_int.call(raw['id'])
  attrs[:type] = raw['type'].presence
  attrs[:name] = raw['name'].presence
  attrs[:description] = raw['description'].presence
  attrs[:internal_description] = raw['internal_description'].presence

  # money / numeric
  attrs[:usd_cost] = parse_decimal.call(raw['usd_cost'])
  attrs[:ticket_cost] = parse_decimal.call(raw['ticket_cost'])
  attrs[:hacker_score] = parse_int.call(raw['hacker_score'])

  # booleans
  attrs[:show_in_carousel] = parse_bool.call(raw['show_in_carousel'])
  attrs[:limited] = parse_bool.call(raw['limited'])
  attrs[:enabled] = parse_bool.call(raw['enabled'])

  # enabled flags per region
  attrs[:enabled_us] = parse_bool.call(raw['enabled_us'])
  attrs[:enabled_eu] = parse_bool.call(raw['enabled_eu'])
  attrs[:enabled_in] = parse_bool.call(raw['enabled_in'])
  attrs[:enabled_ca] = parse_bool.call(raw['enabled_ca'])
  attrs[:enabled_au] = parse_bool.call(raw['enabled_au'])
  attrs[:enabled_xx] = parse_bool.call(raw['enabled_xx'])

  # other ints
  attrs[:one_per_person_ever] = parse_bool.call(raw['one_per_person_ever']) ? true : parse_int.call(raw['one_per_person_ever'])
  attrs[:max_qty] = parse_int.call(raw['max_qty'])
  attrs[:stock] = parse_int.call(raw['stock'])

  # price offsets / percentages
  attrs[:price_offset_us] = parse_decimal.call(raw['price_offset_us'])
  attrs[:price_offset_eu] = parse_decimal.call(raw['price_offset_eu'])
  attrs[:price_offset_in] = parse_decimal.call(raw['price_offset_in'])
  attrs[:price_offset_ca] = parse_decimal.call(raw['price_offset_ca'])
  attrs[:price_offset_au] = parse_decimal.call(raw['price_offset_au'])
  attrs[:price_offset_xx] = parse_decimal.call(raw['price_offset_xx'])

  attrs[:sale_percentage] = parse_decimal.call(raw['sale_percentage'])

  # some string fields that may be long text
  attrs[:hcb_merchant_lock] = raw['hcb_merchant_lock'].presence
  attrs[:hcb_category_lock] = raw['hcb_category_lock'].presence
  attrs[:hcb_keyword_lock] = raw['hcb_keyword_lock'].presence
  attrs[:hcb_preauthorization_instructions] = raw['hcb_preauthorization_instructions'].presence
  attrs[:site_action] = raw['site_action'].presence
  attrs[:unlock_on] = raw['unlock_on'].presence
  attrs[:special] = raw['special'].presence

  # created_at / updated_at
  begin
    attrs[:created_at] = raw['created_at'].present? ? Time.parse(raw['created_at']) : nil
  rescue
    attrs[:created_at] = nil
  end
  begin
    attrs[:updated_at] = raw['updated_at'].present? ? Time.parse(raw['updated_at']) : nil
  rescue
    attrs[:updated_at] = nil
  end

  # JSON-ish columns
  attrs[:agh_contents] = parse_json_like.call(raw['agh_contents'])

  # Trim any empty string values to nil for other columns
  attrs.each { |k, v| attrs[k] = nil if v == '' }

  # Remove id from assignable attributes (we'll use it to find the record)
  record_id = attrs.delete(:id)

  if record_id.nil?
    puts "Skipping row without id: #{raw.inspect}"
    next
  end

  # find_or_initialize and update attributes
  shop_item = ShopItem.find_or_initialize_by(id: record_id)

  # assign attributes — be careful: if your model protects some columns,
  # you can selectively assign instead of assign_attributes.
  begin
    shop_item.assign_attributes(attrs.compact)
  rescue => e
    puts "Error assigning attributes for id=#{record_id}: #{e.message}"
    puts "Attrs: #{attrs.inspect}"
    next
  end

  # If created_at/updated_at were provided and the record is new, set them forcibly after save
  begin
    shop_item.save!(validate: true)
    if attrs[:created_at] || attrs[:updated_at]
      # bypass AR callbacks to set timestamps precisely
      update_attrs = {}
      update_attrs[:created_at] = attrs[:created_at] if attrs[:created_at]
      update_attrs[:updated_at] = attrs[:updated_at] if attrs[:updated_at]
      ShopItem.where(id: shop_item.id).update_all(update_attrs) if update_attrs.any?
    end
    puts "Saved ShopItem id=#{shop_item.id} (#{shop_item.name})"
  rescue => e
    puts "Failed to save ShopItem id=#{record_id}: #{e.class} - #{e.message}"
    puts e.backtrace.take(10).join("\n")
  end
end

puts "Done seeding shop items."
