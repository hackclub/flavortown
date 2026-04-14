class AddReasonQualityToVotes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :votes, :reason_quality_label, :string
    add_column :votes, :reason_quality_score, :float

    add_index :votes, :reason_quality_label, algorithm: :concurrently
  end
end
