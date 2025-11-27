class CreateShopCardGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_card_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shop_item, null: false, foreign_key: true
      t.string :hcb_grant_hashid
      t.integer :expected_amount_cents
      t.timestamps
    end
  end
end
