class AddVerificationStatusToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :verification_status, :string, default: "needs_submission", null: false
    add_column :users, :slack_id, :string
  end
end
