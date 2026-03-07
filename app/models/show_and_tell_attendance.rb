# == Schema Information
#
# Table name: show_and_tell_attendances
#
#  id                       :bigint           not null, primary key
#  date                     :date
#  give_presentation_payout :boolean          default(FALSE), not null
#  payout_given             :boolean          default(FALSE), not null
#  payout_given_at          :datetime
#  winner                   :boolean          default(FALSE), not null
#  winner_payout_given      :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  payout_given_by_id       :bigint
#  project_id               :bigint
#  user_id                  :bigint           not null
#
# Indexes
#
#  index_show_and_tell_attendances_on_payout_given_by_id  (payout_given_by_id)
#  index_show_and_tell_attendances_on_project_id          (project_id)
#  index_show_and_tell_attendances_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (payout_given_by_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class ShowAndTellAttendance < ApplicationRecord
  include Ledgerable

  belongs_to :user
  belongs_to :project, optional: true
  belongs_to :payout_given_by, class_name: "User", optional: true

  PRESENTATION_PAYOUT_AMOUNT = 25
  WINNER_PAYOUT_AMOUNT = 25
  MAX_MONTHLY_PAYOUTS = 2

  def presented_project?
    project_id.present?
  end

  def eligible_for_payout?
    presented_project? && !monthly_payout_limit_reached?
  end

  def monthly_payout_limit_reached?
    return false if date.blank? || user_id.blank?

    month_start = date.beginning_of_month
    month_end = date.end_of_month

    self.class
      .where(user_id: user_id, date: month_start..month_end)
      .where.not(project_id: nil)
      .where.not(id: id)
      .count >= MAX_MONTHLY_PAYOUTS
  end
end
