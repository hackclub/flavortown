class AddVotesCountToPostShipEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :post_ship_events, :votes_count, :integer, default: 0, null: false
  end
end
