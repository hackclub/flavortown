class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sent_by, null: false, foreign_key: { to_table: :users }
      t.string :content
      t.string :block_path

      t.timestamps
    end
  end
end
