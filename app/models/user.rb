# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  display_name                :string
#  email                       :string
#  has_gotten_free_stickers    :boolean          default(FALSE)
#  magic_link_token            :string
#  magic_link_token_expires_at :datetime
#  projects_count              :integer
#  region                      :string
#  verification_status         :string           default("needs_submission"), not null
#  votes_count                 :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_magic_link_token  (magic_link_token) UNIQUE
#  index_users_on_region            (region)
#
class User < ApplicationRecord
  has_paper_trail ignore: [ :projects_count, :votes_count ], on: [ :update, :destroy ]
  has_many :identities, class_name: "User::Identity", dependent: :destroy
  has_many :role_assignments, class_name: "User::RoleAssignment", dependent: :destroy
  has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
  has_many :projects, through: :memberships
  has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :destroy
  has_many :shop_orders, dependent: :destroy
  has_many :votes, dependent: :destroy

  VALID_VERIFICATION_STATUSES = %w[needs_submission pending verified ineligible].freeze

  validates :verification_status, presence: true, inclusion: { in: VALID_VERIFICATION_STATUSES }
  validates :slack_id, presence: true, uniqueness: true

  scope :with_roles, -> { includes(:role_assignments) }

  class << self
    # Add more providers if needed, but make sure to include each one in PROVIDERS inside user/identity.rb; otherwise, the validation will fail.
    def find_by_hackatime(uid) = find_by_provider("hackatime", uid)
    def find_by_idv(uid)       = find_by_provider("idv", uid)

    private

    def find_by_provider(provider, uid)
      joins(:identities).find_by(user_identities: { provider:, uid: })
    end
  end

  User::RoleAssignment.roles.each_key do |role_name|
    # ie. admin?
    define_method "#{role_name}?" do
      if role_assignments.loaded?
        role_assignments.any? { |r| r.role == role_name }
      else
        role_assignments.exists?(role: role_name)
      end
    end

    # ie. make_admin!
    define_method "make_#{role_name}!" do
      role_assignments.find_or_create_by!(role: role_name)
    end
  end

  def has_hackatime?
    identities.exists?(provider: "hackatime")
  end

  def has_identity_linked?
    verification_status != "needs_submission"
  end

  def identity_verified?
    verification_status == "verified"
  end

  def setup_complete?
    has_hackatime? && has_identity_linked?
  end

  def highest_role
    role_assignments.min_by { |a| User::RoleAssignment.roles[a.role] }&.role&.titleize || "User"
  end
  def promote_to_big_leagues!
    role = ::Role.find_by(name: "super_admin")
    role_assignments.find_or_create_by!(role: role) if role
  end

  def generate_magic_link_token!
    self.magic_link_token = SecureRandom.urlsafe_base64(32)
    self.magic_link_token_expires_at = 15.minutes.from_now
    save!
  end

  def magic_link_valid?
    magic_link_token.present? && magic_link_token_expires_at.present? && magic_link_token_expires_at > Time.current
  end

  def clear_magic_link_token!
    update!(magic_link_token: nil, magic_link_token_expires_at: nil)
  end

  def balance
    # TODO: implement payouts
    0
  end

  def address
    # TODO: add on HCA address imports
    {
      name: display_name,
      street1: "15 Falls Rd",
      street2: nil,
      city: "Shelburne",
      state: "VT",
      zip: "05482",
      country: "US",
      email: email
        }
  end
end
