class CreateSidequestEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :sidequest_entries do |t|
      t.references :sidequest, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.string :aasm_state, default: "pending", null: false
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :sidequest_entries, :aasm_state
  end
end
