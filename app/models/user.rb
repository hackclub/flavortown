# == Schema Information
#
# Table name: users
#
#  id             :integer          not null, primary key
#  display_name   :string
#  email          :string
#  projects_count :integer
#  is_admin       :boolean          default(FALSE), not null
#  votes_count    :integer
#  permissions                          :text             default([])
#  internal_notes                       :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class User < ApplicationRecord
  has_many :identities, class_name: "User::Identity", dependent: :destroy

  # Add more providers if needed, but make sure to include each one in PROVIDERS inside user/identity.rb; otherwise, the validation will fail.

  def self.find_by_slack(uid)     = find_by_provider("slack", uid)
  def self.find_by_hackatime(uid) = find_by_provider("hackatime", uid)
  def self.find_by_idv(uid)       = find_by_provider("idv", uid)

  def self.find_by_provider(provider, uid)
    joins(:identities).find_by(user_identities: { provider:, uid: })
  end
  def has_permission?(permission)
    return false if permissions.nil? || permissions.empty?
    permissions.include?(permission.to_s)
  end
  def add_permission(permission)
    current_permissions = (permissions || []).dup
    current_permissions << permission.to_s unless current_permissions.include?(permission.to_s)
    update!(permissions: current_permissions)
  end

  def remove_permission(permission)
    current_permissions = (permissions || []).dup
    current_permissions.delete(permission.to_s)
    update!(permissions: current_permissions)
  end

  def ship_certifier?
    has_permission?("shipcert")
  end
  def ysws_reviewer?
    has_permission?("yswsreviewer")
  end
  def admin?
    is_admin
  end
  private_class_method :find_by_provider
end
