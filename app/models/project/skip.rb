# == Schema Information
#
# Table name: project_skips
# Database name: primary
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_skips_on_project_id              (project_id)
#  index_project_skips_on_user_id                 (user_id)
#  index_project_skips_on_user_id_and_project_id  (user_id,project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Project::Skip < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, uniqueness: { scope: :project_id }
end
