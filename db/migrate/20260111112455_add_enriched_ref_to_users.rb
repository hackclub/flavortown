class AddEnrichedRefToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :enriched_ref, :string
  end
end
