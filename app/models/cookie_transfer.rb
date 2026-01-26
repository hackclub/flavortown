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
class CookieTransfer < ApplicationRecord
  include Ledgerable

  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"

  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :note, length: { maximum: 200 }, allow_blank: true
  validate :sender_has_sufficient_balance
  validate :sender_is_not_recipient

  after_create :create_ledger_entries
  after_commit :notify_users, on: :create

  private

  def sender_has_sufficient_balance
    return unless sender && amount

    if sender.balance < amount
      errors.add(:amount, "exceeds your available balance (#{sender.balance} cookies)")
    end
  end

  def sender_is_not_recipient
    return unless sender && recipient

    if sender_id == recipient_id
      errors.add(:recipient, "cannot be yourself")
    end
  end

  def create_ledger_entries
    ledger_entries.create!(
      user: sender,
      amount: -amount,
      reason: "Transfer to #{recipient.display_name}"
    )

    ledger_entries.create!(
      user: recipient,
      amount: amount,
      reason: "Transfer from #{sender.display_name}"
    )
  end

  def notify_users
    notify_sender
    notify_recipient
  end

  def notify_sender
    return unless sender.slack_balance_notifications? && sender.slack_id.present?

    SendSlackDmJob.perform_later(
      sender.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/sent",
      locals: { transfer: self }
    )
  end

  def notify_recipient
    return unless recipient.slack_balance_notifications? && recipient.slack_id.present?

    SendSlackDmJob.perform_later(
      recipient.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/received",
      locals: { transfer: self }
    )
  end
end
