class CreateFulfillmentPayoutLines < ActiveRecord::Migration[8.1]
  def change
    create_table :fulfillment_payout_lines do |t|
      t.references :fulfillment_payout_run, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :order_count
      t.integer :amount

      t.timestamps
    end
  end
end
