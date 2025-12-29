# == Schema Information
#
# Table name: devlog_versions
#
#  id             :bigint           not null, primary key
#  reverse_diff   :text             not null
#  version_number :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  devlog_id      :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_devlog_versions_on_devlog_id                    (devlog_id)
#  index_devlog_versions_on_devlog_id_and_version_number (devlog_id,version_number) UNIQUE
#  index_devlog_versions_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (devlog_id => post_devlogs.id)
#  fk_rails_...  (user_id => users.id)
#
class DevlogVersion < ApplicationRecord
  belongs_to :devlog, class_name: "Post::Devlog"
  belongs_to :user

  validates :reverse_diff, presence: true
  validates :version_number, presence: true, uniqueness: { scope: :devlog_id }

  # The reverse_diff stores the previous body content.
  # To reconstruct version N, start from current body and apply
  # reverse_diffs backwards from the highest version to N+1.
  #
  # For simplicity, we store the full previous body rather than a patch.
  # This trades some storage space for simpler reconstruction logic.
  # A future optimization could use a proper diff algorithm.
  def previous_body
    reverse_diff
  end
end
