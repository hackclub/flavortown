class CreateUserVoteVerdicts < ActiveRecord::Migration[8.1]
  def change
    create_table :user_vote_verdicts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :verdict, null: false, default: "neutral"
      t.float :quality_score
      t.datetime :assessed_at

      t.timestamps
    end
  end
end
