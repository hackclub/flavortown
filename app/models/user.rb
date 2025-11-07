# == Schema Information
#
# Table name: users
#
#  id             :bigint           not null, primary key
#  display_name   :string
#  email          :string
#  projects_count :integer
#  votes_count    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class User < ApplicationRecord
  has_paper_trail ignore: [ :projects_count, :votes_count ]
  has_many :identities, class_name: "User::Identity", dependent: :destroy
  has_many :role_assignments, class_name: "User::RoleAssignment", dependent: :destroy
  has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
  has_many :projects, through: :memberships
  has_many :roles, through: :role_assignments
  has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :destroy

  class << self
    # Add more providers if needed, but make sure to include each one in PROVIDERS inside user/identity.rb; otherwise, the validation will fail.
    def find_by_slack(uid)     = find_by_provider("slack", uid)
    def find_by_hackatime(uid) = find_by_provider("hackatime", uid)
    def find_by_idv(uid)       = find_by_provider("idv", uid)

    private

    def find_by_provider(provider, uid)
      joins(:identities).find_by(user_identities: { provider:, uid: })
    end
  end

  def admin?
    roles.exists?(name: [ "admin", "super_admin" ])
  end

  def super_admin?
    roles.exists?(name: "super_admin")
  end
  def fraud_dept?
    roles.exists?(name: "fraud_dept")
  end

  def highest_role
    role_hierarchy = [ "super_admin", "admin", "fraud_dept", "project_certifier", "ysws_reviewer", "fulfillment_person" ]
    role_names = roles.pluck(:name).map(&:downcase)
    role_hierarchy.find { |role| role_names.include?(role) }&.titleize || "User"
  end
end
