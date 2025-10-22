class CreatePostDevlogs < ActiveRecord::Migration[8.0]
  def change
    create_table :post_devlogs do |t|
      t.string :body

      t.timestamps
    end
  end
end
