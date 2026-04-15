# == Schema Information
#
# Table name: messages
# Database name: primary
#
#  id         :bigint           not null, primary key
#  block_path :string
#  content    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  sent_by_id :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_messages_on_sent_by_id  (sent_by_id)
#  index_messages_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class Message < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :sent_by, class_name: "User", optional: true

  validates :user, presence: true
  validate :content_or_block_path_present

  private

  def content_or_block_path_present
    if content.blank? && block_path.blank?
      errors.add(:base, "Either content or block path must be provided")
    end
  end
end
