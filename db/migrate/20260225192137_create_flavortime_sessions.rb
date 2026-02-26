class CreateFlavortimeSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :flavortime_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :fingerprint
      t.datetime :last_heartbeat_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :ended_at
      t.integer :discord_shared_seconds, null: false, default: 0

      t.timestamps
    end

    add_index :flavortime_sessions, :fingerprint, unique: true
    add_index :flavortime_sessions, :expires_at
    add_index :flavortime_sessions, [ :user_id, :created_at ]
  end
end
