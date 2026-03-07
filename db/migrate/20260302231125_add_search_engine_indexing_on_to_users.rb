class AddSearchEngineIndexingOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :search_engine_indexing_on, :boolean, default: true, null: false
  end
end
