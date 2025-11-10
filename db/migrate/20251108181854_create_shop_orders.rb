class CreateShopOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shop_item, null: false, foreign_key: true
      t.bigint :shop_card_grant_id
      t.bigint :warehouse_package_id

      t.string :aasm_state
      t.integer :quantity
      t.decimal :frozen_item_price, precision: 6, scale: 2
      t.jsonb :frozen_address
      t.string :external_ref
      t.text :internal_notes

      # Timestamps for state transitions
      t.datetime :awaiting_periodical_fulfillment_at
      t.datetime :fulfilled_at
      t.datetime :rejected_at
      t.datetime :on_hold_at

      # Fulfillment details
      t.string :fulfilled_by
      t.decimal :fulfillment_cost, precision: 6, scale: 2, default: 0.0
      t.string :rejection_reason

      t.timestamps
    end

    # Indexes for performance
    add_index :shop_orders, [ :shop_item_id, :aasm_state ], name: "idx_shop_orders_stock_calc"
    add_index :shop_orders, [ :shop_item_id, :aasm_state, :quantity ], name: "idx_shop_orders_item_state_qty"
    add_index :shop_orders, [ :user_id, :shop_item_id ], name: "idx_shop_orders_user_item_unique"
    add_index :shop_orders, [ :user_id, :shop_item_id, :aasm_state ], name: "idx_shop_orders_user_item_state"
  end
end
