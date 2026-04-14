class AddBridgeFieldsToPostShipEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :post_ship_events, :bridge, :boolean, default: false, null: false
    add_column :post_ship_events, :base_hours, :float
    add_column :post_ship_events, :legacy_payout_deduction, :float
  end
end
