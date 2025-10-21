class CreatePostShipEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :post_ship_events do |t|
      t.string :body

      t.timestamps
    end
  end
end
