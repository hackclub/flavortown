class AddPayoutToPostShipEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :post_ship_events, :hours, :float
    add_column :post_ship_events, :multiplier, :float
    add_column :post_ship_events, :payout, :float
  end
end
