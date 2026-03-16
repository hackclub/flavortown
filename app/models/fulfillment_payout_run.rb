# frozen_string_literal: true

# == Schema Information
#
# Table name: fulfillment_payout_runs
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  approved_at         :datetime
#  period_end          :datetime
#  period_start        :datetime
#  total_amount        :integer
#  total_orders        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_user_id :bigint
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_user_id => users.id)
#
class FulfillmentPayoutRun < ApplicationRecord
  include AASM

  has_paper_trail

  has_many :lines, class_name: "FulfillmentPayoutLine", dependent: :destroy
  belongs_to :approved_by_user, class_name: "User", optional: true

  TICKETS_PER_ORDER = 3

  aasm timestamps: true do
    state :pending_approval, initial: true
    state :approved
    state :rejected

    event :approve do
      transitions from: :pending_approval, to: :approved
      after do
        distribute_payouts!
      end
    end

    event :reject do
      transitions from: :pending_approval, to: :rejected
      after do
        release_orders!
      end
    end
  end

  private

  def distribute_payouts!
    lines.includes(:user).find_each do |line|
      line.user.ledger_entries.create!(
        amount: line.amount,
        reason: "Fulfillment payout for #{line.order_count} #{'order'.pluralize(line.order_count)}",
        created_by: "System",
        ledgerable: line
      )
    end
  end

  def release_orders!
    ShopOrder.where(fulfillment_payout_line: lines).update_all(fulfillment_payout_line_id: nil)
  end
end
