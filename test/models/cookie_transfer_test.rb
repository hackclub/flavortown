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
