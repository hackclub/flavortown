class CreateExtensionUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :extension_usages do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :extension_usages, [ :project_id, :recorded_at ]
    add_index :extension_usages, :recorded_at
  end
end
