# == Schema Information
#
# Table name: show_and_tell_payout_records
#
#  id                 :bigint           not null, primary key
#  date               :date             not null
#  notes              :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  payout_given_by_id :bigint           not null
#
# Indexes
#
#  index_show_and_tell_payout_records_on_date                (date) UNIQUE
#  index_show_and_tell_payout_records_on_payout_given_by_id  (payout_given_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (payout_given_by_id => users.id)
#
class ShowAndTellPayoutRecord < ApplicationRecord
  belongs_to :payout_given_by, class_name: "User"

  validates :date, presence: true, uniqueness: true
end
