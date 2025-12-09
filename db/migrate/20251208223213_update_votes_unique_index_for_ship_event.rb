class UpdateVotesUniqueIndexForShipEvent < ActiveRecord::Migration[8.1]
  def change
    remove_index :votes, [ :user_id, :project_id, :category ], name: "index_votes_on_user_id_and_project_id_and_category"
    add_index :votes, [ :user_id, :ship_event_id, :category ], unique: true
  end
end
