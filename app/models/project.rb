# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  demo_url          :text
#  description       :text
#  memberships_count :integer          default(0), not null
#  readme_url        :text
#  repo_url          :text
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class Project < ApplicationRecord
    has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
    has_many :users, through: :memberships

    has_one_attached :demo_video
    has_one_attached :banner

    validates :title, presence: true, length: { maximum: 120 }
    validates :description, length: { maximum: 1_000 }, allow_blank: true
end
