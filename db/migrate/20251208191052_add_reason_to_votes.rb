class AddReasonToVotes < ActiveRecord::Migration[8.1]
  def change
    add_column :votes, :reason, :text
  end
end
