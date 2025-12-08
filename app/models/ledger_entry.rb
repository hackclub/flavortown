# == Schema Information
#
# Table name: ledger_entries
#
#  id              :bigint           not null, primary key
#  amount          :integer
#  created_by      :string           not null
#  ledgerable_type :string           not null
#  reason          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ledgerable_id   :bigint           not null
#
# Indexes
#
#  index_ledger_entries_on_ledgerable  (ledgerable_type,ledgerable_id)
#
class LedgerEntry < ApplicationRecord
  belongs_to :ledgerable, polymorphic: true

  validates :created_by, presence: true

  after_create :create_audit_log

  private

  def create_audit_log
    return unless ledgerable_type == "User"

    new_balance = ledgerable.balance

    PaperTrail::Version.create!(
      item_type: "User",
      item_id: ledgerable.id,
      event: "balance_adjustment",
      whodunnit: nil,
      object_changes: { balance: [ new_balance - amount, new_balance ], reason: reason, created_by: created_by }.to_yaml
    )
  end
end
