# == Schema Information
#
# Table name: comments
#
#  id               :bigint           not null, primary key
#  body             :text             not null
#  commentable_type :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  commentable_id   :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_comments_on_commentable                 (commentable_type,commentable_id)
#  index_comments_on_commentable_and_created_at  (commentable_type,commentable_id,created_at)
#  index_comments_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Comment < ApplicationRecord
  has_paper_trail

  belongs_to :commentable, polymorphic: true, counter_cache: true
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5000 }

  after_create :notify_slack_channel

  private

  def notify_slack_channel
    PostCreationToSlackJob.perform_later(self)
  end
end
