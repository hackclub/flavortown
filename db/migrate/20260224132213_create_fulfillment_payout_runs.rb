class CreateFulfillmentPayoutRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :fulfillment_payout_runs do |t|
      t.string :aasm_state
      t.datetime :period_start
      t.datetime :period_end
      t.integer :total_orders
      t.integer :total_amount
      t.datetime :approved_at
      t.bigint :approved_by_user_id

      t.timestamps
    end

    add_foreign_key :fulfillment_payout_runs, :users, column: :approved_by_user_id
  end
end
