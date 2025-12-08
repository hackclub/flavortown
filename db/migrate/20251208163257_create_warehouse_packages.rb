class CreateWarehousePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :warehouse_packages do |t|
      t.timestamps
      t.jsonb :frozen_address, null: false
      t.string :theseus_package_id
      t.references :user, null: false, foreign_key: true
    end
  end
end
