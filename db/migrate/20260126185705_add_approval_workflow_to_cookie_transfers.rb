class AddApprovalWorkflowToCookieTransfers < ActiveRecord::Migration[8.1]
  def change
    add_column :cookie_transfers, :aasm_state, :string, default: "pending", null: false
    add_column :cookie_transfers, :reviewed_by_id, :bigint
    add_column :cookie_transfers, :reviewed_at, :datetime
    add_column :cookie_transfers, :rejection_reason, :string
    add_index :cookie_transfers, :aasm_state
    add_foreign_key :cookie_transfers, :users, column: :reviewed_by_id
  end
end
