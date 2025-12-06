class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :project, null: false, foreign_key: true
      t.string :reason, null: false
      t.text :details, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :reports, [:reporter_id, :project_id], unique: true
  end
end
