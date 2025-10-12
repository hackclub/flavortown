# == Schema Information
#
# Table name: users
#
#  id             :integer          not null, primary key
#  display_name   :string
#  email          :string
#  projects_count :integer
#  votes_count    :integer
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

  private_class_method :find_by_provider
end
