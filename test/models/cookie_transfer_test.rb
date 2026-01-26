# == Schema Information
#
# Table name: cookie_transfers
#
#  id           :bigint           not null, primary key
#  amount       :integer          not null
#  note         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  recipient_id :bigint           not null
#  sender_id    :bigint           not null
#
# Indexes
#
#  index_cookie_transfers_on_recipient_id  (recipient_id)
#  index_cookie_transfers_on_sender_id     (sender_id)
#
# Foreign Keys
#
#  fk_rails_...  (recipient_id => users.id)
#  fk_rails_...  (sender_id => users.id)
#
require "test_helper"

class CookieTransferTest < ActiveSupport::TestCase
  def setup
    @sender = users(:one)
    @recipient = users(:two)

    @sender.ledger_entries.create!(
      amount: 100,
      reason: "Test grant",
      ledgerable: @sender
    )
  end

  test "valid transfer creates ledger entries" do
    transfer = CookieTransfer.new(
      sender: @sender,
      recipient: @recipient,
      amount: 50,
      note: "Thanks for helping!"
    )

    assert_difference -> { LedgerEntry.count }, 2 do
      transfer.save!
    end

    assert_equal 50, @sender.reload.balance
    assert_equal 50, @recipient.reload.balance
  end

  test "amount must be positive" do
    transfer = CookieTransfer.new(
      sender: @sender,
      recipient: @recipient,
      amount: 0
    )

    assert_not transfer.valid?
    assert_includes transfer.errors[:amount], "must be greater than 0"
  end

  test "sender cannot be recipient" do
    transfer = CookieTransfer.new(
      sender: @sender,
      recipient: @sender,
      amount: 10
    )

    assert_not transfer.valid?
    assert_includes transfer.errors[:recipient], "cannot be yourself"
  end

  test "sender must have sufficient balance" do
    transfer = CookieTransfer.new(
      sender: @sender,
      recipient: @recipient,
      amount: 200
    )

    assert_not transfer.valid?
    assert transfer.errors[:amount].any? { |e| e.include?("exceeds your available balance") }
  end

  test "note is optional and limited to 200 characters" do
    transfer = CookieTransfer.new(
      sender: @sender,
      recipient: @recipient,
      amount: 10,
      note: "a" * 201
    )

    assert_not transfer.valid?
    assert transfer.errors[:note].any?
  end
end
