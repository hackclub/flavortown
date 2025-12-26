class CreateYswsReviewDevlogApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :ysws_review_devlog_approvals do |t|
      t.references :ysws_review_submission, null: false, foreign_key: true
      t.references :post_devlog, null: false, foreign_key: { to_table: :post_devlogs }
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      t.boolean :approved, default: false, null: false
      t.integer :approved_seconds, default: 0, null: false
      t.integer :original_seconds, default: 0, null: false
      t.text :internal_notes
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :ysws_review_devlog_approvals, [:ysws_review_submission_id, :post_devlog_id],
              unique: true, name: "idx_ysws_devlog_approvals_unique"
  end
end
