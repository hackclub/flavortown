# frozen_string_literal: true

# borrowed code from the summer of making
module Shop
  module Regionalizable
    extend ActiveSupport::Concern

    REGIONS = {
      "US" => { name: "United States", countries: [ "US" ] },
      "EU" => { name: "EU", countries: [ "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE" ] },
      "UK" => { name: "United Kingdom", countries: [ "GB" ] },
      "IN" => { name: "India", countries: [ "IN" ] },
      "CA" => { name: "Canada", countries: [ "CA" ] },
      "AU" => { name: "Australia", countries: [ "AU", "NZ" ] },
      "XX" => { name: "Rest of World", countries: [] } # Special case - everything else
    }.freeze

    REGION_CODES = REGIONS.keys.freeze

    class_methods do
      def region_columns
        @region_columns ||= REGION_CODES.flat_map do |code|
          [ "enabled_#{code.downcase}", "price_offset_#{code.downcase}" ]
        end
      end
    end

    included do
      # Define scope methods for each region
      REGION_CODES.each do |code|
        column = "enabled_#{code.downcase}".to_sym
        scope :"enabled_in_#{code.downcase}", -> { where(column => true) }
        scope :"disabled_in_#{code.downcase}", -> { where(column => [ false, nil ]) }
      end
    end

    def any_region_enabled?
      REGION_CODES.any? { |code| send("enabled_#{code.downcase}") }
    end

    def enabled_in_region?(region_code)
      return false unless REGION_CODES.include?(region_code.upcase)

      return true unless any_region_enabled?

      # If enabled for this specific region, return true
      return true if send("enabled_#{region_code.downcase}")

      # If enabled for XX (Rest of World), item is available everywhere
      enabled_xx
    end

    def price_for_region(region_code)
      region_code = region_code.upcase
      region_code = "XX" unless REGION_CODES.include?(region_code)

      # Get region-specific offset, falling back to XX offset if not set
      region_offset = send("price_offset_#{region_code.downcase}")
      offset = region_offset.present? ? region_offset : (send("price_offset_xx") || 0)

      base_price = ticket_cost + offset
      apply_sale_discount(base_price)
    end

    private

    def apply_sale_discount(price)
      return price unless sale_percentage.present? && sale_percentage > 0 && sale_percentage <= 100

      discount_multiplier = (100 - sale_percentage) / 100.0
      discounted_price = price * discount_multiplier
      discounted_price.ceil
    end

    def regions_enabled
      REGION_CODES.select { |code| enabled_in_region?(code) }
    end

    def self.country_to_region(country_code)
      return "XX" if country_code.blank?

      REGIONS.each do |region_code, config|
        next if region_code == "XX" # Skip "rest of world" in initial search
        return region_code if config[:countries].include?(country_code.upcase)
      end

      "XX" # Default to "rest of world"
    end

    def self.region_name(region_code)
      REGIONS.dig(region_code.upcase, :name) || "Unknown Region"
    end

    def self.countries_for_region(region_code)
      REGIONS.dig(region_code.upcase, :countries) || []
    end
  end
end
