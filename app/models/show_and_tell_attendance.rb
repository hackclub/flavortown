# == Schema Information
#
# Table name: show_and_tell_attendances
#
#  id         :bigint           not null, primary key
#  date       :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_show_and_tell_attendances_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ShowAndTellAttendance < ApplicationRecord
  belongs_to :user
end
