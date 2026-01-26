# == Schema Information
#
# Table name: cookie_transfers
#
#  id               :bigint           not null, primary key
#  aasm_state       :string           default("pending"), not null
#  amount           :integer          not null
#  note             :string
#  rejection_reason :string
#  reviewed_at      :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  recipient_id     :bigint           not null
#  reviewed_by_id   :bigint
#  sender_id        :bigint           not null
#
# Indexes
#
#  index_cookie_transfers_on_aasm_state    (aasm_state)
#  index_cookie_transfers_on_recipient_id  (recipient_id)
#  index_cookie_transfers_on_sender_id     (sender_id)
#
# Foreign Keys
#
#  fk_rails_...  (recipient_id => users.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (sender_id => users.id)
#
class CookieTransfer < ApplicationRecord
  include AASM
  include Ledgerable

  has_paper_trail

  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :note, length: { maximum: 200 }, allow_blank: true
  validate :sender_has_sufficient_balance
  validate :sender_is_not_recipient
  validate :sender_is_verified
  validate :recipient_is_verified

  after_commit :notify_pending_transfer, on: :create

  aasm timestamps: true do
    state :pending, initial: true
    state :approved
    state :rejected

    event :approve do
      transitions from: :pending, to: :approved
      after do
        create_ledger_entries
        notify_users_approved
      end
    end

    event :reject do
      transitions from: :pending, to: :rejected
      before do |reason|
        self.rejection_reason = reason
      end
      after do
        notify_sender_rejected
      end
    end
  end

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

  def sender_is_verified
    return unless sender

    unless sender.verification_verified?
      errors.add(:base, "You must complete identity verification to transfer cookies")
    end
  end

  def recipient_is_verified
    return unless recipient

    unless recipient.verification_verified?
      errors.add(:recipient, "must have completed identity verification to receive cookies")
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

  def notify_pending_transfer
    return unless sender.slack_balance_notifications? && sender.slack_id.present?

    SendSlackDmJob.perform_later(
      sender.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/pending",
      locals: { transfer: self }
    )
  end

  def notify_users_approved
    notify_sender_approved
    notify_recipient_approved
  end

  def notify_sender_approved
    return unless sender.slack_balance_notifications? && sender.slack_id.present?

    SendSlackDmJob.perform_later(
      sender.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/sent",
      locals: { transfer: self }
    )
  end

  def notify_recipient_approved
    return unless recipient.slack_balance_notifications? && recipient.slack_id.present?

    SendSlackDmJob.perform_later(
      recipient.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/received",
      locals: { transfer: self }
    )
  end

  def notify_sender_rejected
    return unless sender.slack_balance_notifications? && sender.slack_id.present?

    SendSlackDmJob.perform_later(
      sender.slack_id,
      nil,
      blocks_path: "notifications/cookie_transfers/rejected",
      locals: { transfer: self }
    )
  end
end
