class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :commentable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    add_index :comments, [ :commentable_type, :commentable_id, :created_at ], name: "index_comments_on_commentable_and_created_at"
  end
end
