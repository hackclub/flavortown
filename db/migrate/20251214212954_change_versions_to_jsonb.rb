class ChangeVersionsToJsonb < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # First, convert existing YAML data to JSON using Ruby
    # PostgreSQL cannot parse YAML natively
    say_with_time "Converting YAML records to JSON" do
      convert_yaml_to_json
    end

    # Now change column types to jsonb
    change_column :versions, :object, :jsonb, using: "NULLIF(object, '')::jsonb", default: {}
    change_column :versions, :object_changes, :jsonb, using: "NULLIF(object_changes, '')::jsonb", default: {}

    # Add GIN indexes for faster JSON queries
    add_index :versions, :object, using: :gin, name: "index_versions_on_object", algorithm: :concurrently
    add_index :versions, :object_changes, using: :gin, name: "index_versions_on_object_changes", algorithm: :concurrently
  end

  def down
    remove_index :versions, name: "index_versions_on_object", if_exists: true
    remove_index :versions, name: "index_versions_on_object_changes", if_exists: true

    change_column :versions, :object, :text
    change_column :versions, :object_changes, :text
  end

  private

  def convert_yaml_to_json
    require "yaml"

    converted = 0
    # Process in batches to avoid memory issues
    PaperTrail::Version.find_each(batch_size: 500) do |version|
      updates = {}

      # Convert object column if it contains YAML
      if version.object.is_a?(String) && version.object.start_with?("---")
        begin
          parsed = YAML.safe_load(version.object, permitted_classes: [ Time, Date, DateTime, BigDecimal, Symbol, ActiveSupport::TimeWithZone ])
          updates[:object] = parsed.to_json
        rescue => e
          Rails.logger.warn "Failed to convert version #{version.id} object: #{e.message}"
          updates[:object] = "{}"
        end
      elsif version.object.blank?
        updates[:object] = "{}"
      end

      # Convert object_changes column if it contains YAML
      if version.object_changes.is_a?(String) && version.object_changes.start_with?("---")
        begin
          parsed = YAML.safe_load(version.object_changes, permitted_classes: [ Time, Date, DateTime, BigDecimal, Symbol, ActiveSupport::TimeWithZone ])
          updates[:object_changes] = parsed.to_json
        rescue => e
          Rails.logger.warn "Failed to convert version #{version.id} object_changes: #{e.message}"
          updates[:object_changes] = "{}"
        end
      elsif version.object_changes.blank?
        updates[:object_changes] = "{}"
      end

      if updates.any?
        version.update_columns(updates)
        converted += 1
      end
    end

    converted
  end
end
