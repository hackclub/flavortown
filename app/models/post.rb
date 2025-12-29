# == Schema Information
#
# Table name: posts
#
#  id            :bigint           not null, primary key
#  postable_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  postable_id   :bigint
#  project_id    :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_posts_on_postable_type_and_postable_id  (postable_type,postable_id) UNIQUE
#  index_posts_on_project_id                     (project_id)
#  index_posts_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Post < ApplicationRecord
    belongs_to :project, touch: true
    # optional because it can be a system post – achievements, milestones, well-done/magic happening, etc –
    # integeration – git remotes – or a user post
    belongs_to :user, optional: true

    delegated_type :postable, types: %w[Post::Devlog Post::ShipEvent Post::FireEvent Post::GitCommit]

    # For loading devlogs including soft-deleted ones (for admins)
    belongs_to :devlog_with_deleted,
               -> { unscope(where: :deleted_at) },
               class_name: "Post::Devlog",
               foreign_key: :postable_id,
               optional: true

    def postable_with_deleted
      return postable unless postable_type == "Post::Devlog"
      devlog_with_deleted
    end

    after_commit :invalidate_project_time_cache, on: [ :create, :destroy ]
    after_commit :increment_devlogs_count, on: :create
    after_commit :decrement_devlogs_count, on: :destroy

    scope :devlogs, -> { where(postable_type: "Post::Devlog") }

    private

    def invalidate_project_time_cache
      return unless postable_type == "Post::Devlog"

      Rails.cache.delete("project/#{project_id}/time_seconds")
    end

    def increment_devlogs_count
      return unless postable_type == "Post::Devlog"

      Project.unscoped.where(id: project_id).update_counters(devlogs_count: 1)
    end

    def decrement_devlogs_count
      return unless postable_type == "Post::Devlog"

      Project.unscoped.where(id: project_id).update_counters(devlogs_count: -1)
    end
end
