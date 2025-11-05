class CreateShopItems < ActiveRecord::Migration[7.1]
  def change
    create_table :shop_items, id: :bigint do |t|
      t.jsonb :agh_contents
      t.timestamp :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :description
      t.boolean :enabled
      t.boolean :enabled_au
      t.boolean :enabled_ca
      t.boolean :enabled_eu
      t.boolean :enabled_in
      t.boolean :enabled_us
      t.boolean :enabled_xx
      t.integer :hacker_score
      t.string :hcb_category_lock
      t.string :hcb_keyword_lock
      t.string :hcb_merchant_lock
      t.text :hcb_preauthorization_instructions
      t.string :internal_description
      t.boolean :limited
      t.integer :max_qty
      t.string :name
      t.boolean :one_per_person_ever
      t.decimal :price_offset_au
      t.decimal :price_offset_ca
      t.decimal :price_offset_eu
      t.decimal :price_offset_in
      t.decimal :price_offset_us
      t.decimal :price_offset_xx
      t.integer :sale_percentage
      t.boolean :show_in_carousel
      t.integer :site_action
      t.boolean :special
      t.integer :stock
      t.decimal :ticket_cost
      t.string :type
      t.date :unlock_on
      t.timestamp :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.decimal :usd_cost
    end
  end
end
