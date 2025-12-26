class CreateYswsReviewSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :ysws_review_submissions do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      t.integer :status, default: 0, null: false
      t.datetime :reviewed_at

      t.timestamps
    end
  end
end
