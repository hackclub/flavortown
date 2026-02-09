class CreateReportReviewTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :report_review_tokens do |t|
      t.references :report, null: false, foreign_key: { to_table: :project_reports }
      t.string :action, null: false
      t.string :token, null: false
      t.datetime :used_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :report_review_tokens, :token, unique: true
    add_index :report_review_tokens, [ :report_id, :action ], unique: true
  end
end
