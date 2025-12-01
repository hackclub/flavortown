class AddTrackingFieldsToVotes < ActiveRecord::Migration[8.1]
  def change
    add_column :votes, :time_taken_to_vote, :integer
    add_column :votes, :repo_url_clicked, :boolean
    add_column :votes, :demo_url_clicked, :boolean
  end
end
