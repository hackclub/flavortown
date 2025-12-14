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
#  user_id         :bigint           not null
#
# Indexes
#
#  index_ledger_entries_on_ledgerable  (ledgerable_type,ledgerable_id)
#  index_ledger_entries_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class LedgerEntryTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
