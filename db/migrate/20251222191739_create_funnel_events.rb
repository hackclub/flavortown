class CreateFunnelEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :funnel_events do |t|
      t.string :event_name, null: false
      t.bigint :user_id, null: true
      t.string :email, null: true
      t.jsonb :properties, default: {}, null: false

      t.timestamps null: false
    end

    add_index :funnel_events, :user_id
    add_index :funnel_events, :email
    add_index :funnel_events, :event_name
    add_index :funnel_events, :created_at
    add_index :funnel_events, [ :event_name, :created_at ]
  end
end
