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

  # Add more providers if needed, but make sure to include each one in PROVIDERS inside user/identity.rb; otherwise, the validation will fail.

  def self.find_by_slack(uid)     = find_by_provider("slack", uid)
  def self.find_by_hackatime(uid) = find_by_provider("hackatime", uid)
  def self.find_by_idv(uid)       = find_by_provider("idv", uid)

  def self.find_by_provider(provider, uid)
    joins(:identities).find_by(user_identities: { provider:, uid: })
  end
  def is_admin
    roles.exists?(name:"admin")
  end
  def is_fraud_dept
    roles.exists?(name:"fraud_dept")
  end
  def can_use_blazer
    return is_admin() 
  end
  
  def can_use_flipper
    return is_admin()
  end

  def can_use_admin_endpoints
      is_admin() || is_fraud_dept()
  end
  private_class_method :find_by_provider
end
