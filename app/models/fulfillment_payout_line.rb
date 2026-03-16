# frozen_string_literal: true

# == Schema Information
#
# Table name: fulfillment_payout_lines
#
#  id                        :bigint           not null, primary key
#  amount                    :integer
#  order_count               :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  fulfillment_payout_run_id :bigint           not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_fulfillment_payout_lines_on_fulfillment_payout_run_id  (fulfillment_payout_run_id)
#  index_fulfillment_payout_lines_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (fulfillment_payout_run_id => fulfillment_payout_runs.id)
#  fk_rails_...  (user_id => users.id)
#
class FulfillmentPayoutLine < ApplicationRecord
  include Ledgerable

  belongs_to :fulfillment_payout_run
  belongs_to :user

  has_many :shop_orders, dependent: :nullify
end
