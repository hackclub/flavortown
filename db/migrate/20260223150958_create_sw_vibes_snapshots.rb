class CreateSwVibesSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :sw_vibes_snapshots do |t|
      t.date :recorded_date, null: false
      t.boolean :result
      t.text :reason
      t.jsonb :payload, default: {}

      t.timestamps
    end

    add_index :sw_vibes_snapshots, :recorded_date, unique: true
  end
end
