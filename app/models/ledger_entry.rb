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
end
