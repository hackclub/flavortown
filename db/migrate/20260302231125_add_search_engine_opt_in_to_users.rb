class AddSearchEngineOptInToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :search_engine_opt_in, :boolean, default: false, null: false
  end
end
