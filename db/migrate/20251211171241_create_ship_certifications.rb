class CreateShipCertifications < ActiveRecord::Migration[8.0]
  def change
    create_table :ship_certifications do |t|
      t.references :project, null: false, foreign_key: true
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      t.string :aasm_state, null: false, default: "pending"
      t.text :feedback
      t.datetime :decided_at

      t.timestamps
    end

    add_index :ship_certifications, [:project_id, :created_at]
  end
end
