class CreateShipCertifications < ActiveRecord::Migration[8.1]
  def change
    create_table :ship_certifications do |t|
      t.references :project, null: false, foreign_key: true
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      t.references :ysws_returned_by, null: true, foreign_key: { to_table: :users }
      t.integer :judgement, default: 0, null: false

      t.timestamps
    end
  end
end
