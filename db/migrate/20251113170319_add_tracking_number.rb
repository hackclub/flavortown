class AddTrackingNumber < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :tracking_number, :string
  end
end
