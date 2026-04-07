class AddSearchEngineIndexingOffToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_vote_deficit, :boolean, default: true, null: false
  end
end
