class CreatePostFireEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :post_fire_events do |t|
      t.string :body

      t.timestamps
    end
  end
end
