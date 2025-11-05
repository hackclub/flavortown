# == Schema Information
#
# Table name: posts
#
#  id            :bigint           not null, primary key
#  postable_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  postable_id   :string
#  project_id    :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_posts_on_project_id  (project_id)
#  index_posts_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Post < ApplicationRecord
    belongs_to :project
    # optional because it can be a system post – achievements, milestones, well-done/magic happening, etc –
    # integeration – git remotes – or a user post
    belongs_to :user, optional: true

    delegated_type :postable, types: %w[Post::Devlog Post::ShipEvent]
end
