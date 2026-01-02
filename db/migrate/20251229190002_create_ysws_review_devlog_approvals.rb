class CreateYswsReviewDevlogApprovals < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:ysws_review_devlog_approvals)

    create_table :ysws_review_devlog_approvals do |t|
      t.references :ysws_review_submission,
                   null: false,
                   foreign_key: { to_table: :ysws_review_submissions },
                   index: { name: "idx_on_ysws_review_submission_id_8b0db5beb0" }
      t.references :post_devlog,
                   null: false,
                   foreign_key: { to_table: :post_devlogs },
                   index: true
      t.references :reviewer,
                   foreign_key: { to_table: :users },
                   index: true

      t.boolean :approved, null: false, default: false
      t.integer :original_seconds, null: false, default: 0
      t.integer :approved_seconds, null: false, default: 0
      t.text :internal_notes
      t.datetime :reviewed_at

      t.timestamps
    end

    unless index_exists?(:ysws_review_devlog_approvals, [:ysws_review_submission_id, :post_devlog_id])
      add_index :ysws_review_devlog_approvals,
                [:ysws_review_submission_id, :post_devlog_id],
                unique: true,
                name: "idx_ysws_devlog_approvals_unique"
    end
  end
end
