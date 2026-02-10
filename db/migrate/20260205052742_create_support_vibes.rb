class CreateSupportVibes < ActiveRecord::Migration[8.1]
  def change
    create_table :support_vibes do |t|
      t.datetime :period_start
      t.datetime :period_end
      t.decimal :overall_sentiment, precision: 3, scale: 2
      t.jsonb :concerns, default: []
      t.jsonb :notable_quotes, default: []
      t.string :rating

      t.timestamps
    end

    add_index :support_vibes, :period_start
  end
end
