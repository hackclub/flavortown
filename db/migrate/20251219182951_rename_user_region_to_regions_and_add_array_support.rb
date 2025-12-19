class RenameUserRegionToRegionsAndAddArraySupport < ActiveRecord::Migration[8.1]
  def up
    # Add the new regions array column
    add_column :users, :regions, :string, array: true, default: []

    # Migrate existing data: convert single region to array
    execute <<-SQL
      UPDATE users
      SET regions = ARRAY[region]
      WHERE region IS NOT NULL AND region != ''
    SQL

    # Remove old region column
    remove_index :users, :region
    remove_column :users, :region
  end

  def down
    # Add back the single region column
    add_column :users, :region, :string
    add_index :users, :region

    # Migrate data back: take first region from array
    execute <<-SQL
      UPDATE users
      SET region = regions[1]
      WHERE array_length(regions, 1) > 0
    SQL

    # Remove the array column
    remove_column :users, :regions
  end
end
