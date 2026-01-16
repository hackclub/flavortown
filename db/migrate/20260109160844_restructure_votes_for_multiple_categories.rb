class RestructureVotesForMultipleCategories < ActiveRecord::Migration[8.1]
  def change
    drop_table :votes, if_exists: true

    create_table :votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :ship_event, null: false, foreign_key: { to_table: :post_ship_events }

      t.integer :originality_score
      t.integer :technical_score
      t.integer :usability_score
      t.integer :storytelling_score

      t.text :reason
      t.boolean :demo_url_clicked, default: false
      t.boolean :repo_url_clicked, default: false
      t.integer :time_taken_to_vote

      t.timestamps
    end

    add_index :votes, [ :user_id, :ship_event_id ], unique: true
  end
end
