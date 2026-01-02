class CreateYswsReviewSubmissions < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:ysws_review_submissions)

    create_table :ysws_review_submissions do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.references :reviewer, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.datetime :reviewed_at

      t.timestamps
    end
  end
end
