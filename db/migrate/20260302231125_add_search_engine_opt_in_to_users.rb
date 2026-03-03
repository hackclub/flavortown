class AddSearchEngineOptInToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :search_engine_opt_in, :boolean, default: true, null: false
  end
end
