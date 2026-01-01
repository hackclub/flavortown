class CreateDevlogVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :devlog_versions do |t|
      t.references :devlog, null: false, foreign_key: { to_table: :post_devlogs }
      t.references :user, null: false, foreign_key: true
      t.text :reverse_diff, null: false
      t.integer :version_number, null: false

      t.timestamps
    end

    add_index :devlog_versions, %i[devlog_id version_number], unique: true
  end
end
