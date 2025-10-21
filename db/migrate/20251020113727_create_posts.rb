class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :postable_type
      t.string :postable_id

      t.timestamps
    end
  end
end
