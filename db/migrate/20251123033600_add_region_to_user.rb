class AddRegionToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :region, :string
    add_index :users, :region
  end
end
