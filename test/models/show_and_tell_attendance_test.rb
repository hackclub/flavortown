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
require "test_helper"

class ShowAndTellAttendanceTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
