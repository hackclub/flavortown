# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  display_name                :string
#  email                       :string
#  first_name                  :string
#  has_gotten_free_stickers    :boolean          default(FALSE)
#  has_roles                   :boolean          default(TRUE), not null
#  last_name                   :string
#  magic_link_token            :string
#  magic_link_token_expires_at :datetime
#  projects_count              :integer
#  region                      :string
#  synced_at                   :datetime
#  tutorial_steps_completed    :string           default([]), is an Array
#  verification_status         :string           default("needs_submission"), not null
#  votes_count                 :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_email             (email)
#  index_users_on_magic_link_token  (magic_link_token) UNIQUE
#  index_users_on_region            (region)
#  index_users_on_slack_id          (slack_id) UNIQUE
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

  include Ledgerable

  VALID_VERIFICATION_STATUSES = %w[needs_submission pending verified ineligible].freeze

  validates :verification_status, presence: true, inclusion: { in: VALID_VERIFICATION_STATUSES }
  validates :slack_id, presence: true, uniqueness: true

  scope :with_roles, -> { includes(:role_assignments) }

  # use me! i'm full of symbols!! disregard the foul tutorial_steps_completed, she lies
  def tutorial_steps = tutorial_steps_completed&.map(&:to_sym) || []

  def tutorial_step_completed?(slug) = tutorial_steps.include?(slug)

  def complete_tutorial_step!(slug)
    update!(tutorial_steps_completed: tutorial_steps + [ slug ]) unless tutorial_step_completed?(slug)
  end

  def revoke_tutorial_step!(slug)
    update!(tutorial_steps_completed: tutorial_steps - [ slug ]) if tutorial_step_completed?(slug)
  end

  def attempt_to_refresh_verification_status
    # if user has tutorial step finished, skip
    return unless tutorial_step_completed?(:identity_verified)
    # if user has verified, skip
    return unless verifi
  end

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
    ledger_entries.sum(:amount)
  end

  def cancel_shop_order(order_id)
    order = shop_orders.find(order_id)
    return { success: false, error: "Your order can not be canceled" } unless order.pending?

    order.refund!
    { success: true, order: order }
  rescue ActiveRecord::RecordNotFound
    { success: false, error: "wuh" }
  end

  def addresses
    identity = identities.find_by(provider: "hack_club")
    return [] unless identity&.access_token.present?

    identity_payload = HCAService.identity(identity.access_token)
    identity_payload["addresses"] || []
  end
end
