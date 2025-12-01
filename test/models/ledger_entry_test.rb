# == Schema Information
#
# Table name: ledger_entries
#
#  id              :bigint           not null, primary key
#  amount          :integer
#  ledgerable_type :string           not null
#  reason          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :bigint           not null
#  ledgerable_id   :bigint           not null
#
# Indexes
#
#  index_ledger_entries_on_created_by_id  (created_by_id)
#  index_ledger_entries_on_ledgerable     (ledgerable_type,ledgerable_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#
require "test_helper"

class LedgerEntryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
