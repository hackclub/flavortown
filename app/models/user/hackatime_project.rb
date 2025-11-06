# app/models/user/hackatime_project.rb
# == Schema Information
#
# Table name: user_hackatime_projects
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_hackatime_projects_on_project_id        (project_id)
#  index_user_hackatime_projects_on_user_id           (user_id)
#  index_user_hackatime_projects_on_user_id_and_name  (user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class User::HackatimeProject < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  EXCLUDED_NAMES = [ "Other", "<<LAST_PROJECT>>" ].freeze

  validates :name, presence: true
  # this ensures that the key can be used in js 1 project
  validates :name, uniqueness: { scope: :user_id }
  validates :name, exclusion: { in: EXCLUDED_NAMES, message: "is excluded" }
end
