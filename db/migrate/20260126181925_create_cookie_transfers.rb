class CreateCookieTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :cookie_transfers do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.integer :amount, null: false
      t.string :note

      t.timestamps
    end
  end
end
