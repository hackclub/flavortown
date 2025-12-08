class AddShipEventToVotes < ActiveRecord::Migration[8.1]
  def change
    add_reference :votes, :ship_event, null: true, foreign_key: { to_table: :post_ship_events }
  end
end
