class AddSearchEngineIndexingOffToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :search_engine_indexing_off, :boolean, default: false, null: false
  end
end
