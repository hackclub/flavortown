# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  api_key                     :string
#  banned                      :boolean          default(FALSE), not null
#  banned_at                   :datetime
#  banned_reason               :text
#  display_name                :string
#  email                       :string
#  first_name                  :string
#  has_gotten_free_stickers    :boolean          default(FALSE)
#  roles                       :string           default([]), is an Array
#  hcb_email                   :string
#  last_name                   :string
#  magic_link_token            :string
#  magic_link_token_expires_at :datetime
#  projects_count              :integer
#  region                      :string
#  send_votes_to_slack         :boolean          default(FALSE), not null
#  session_token               :string
#  synced_at                   :datetime
#  tutorial_steps_completed    :string           default([]), is an Array
#  verification_status         :string           default("needs_submission"), not null
#  vote_anonymously            :boolean          default(FALSE), not null
#  votes_count                 :integer
#  ysws_eligible               :boolean          default(FALSE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_email             (email)
#  index_users_on_magic_link_token  (magic_link_token) UNIQUE
#  index_users_on_region            (region)
#  index_users_on_session_token     (session_token) UNIQUE
#  index_users_on_slack_id          (slack_id) UNIQUE
#
class User < ApplicationRecord
  has_paper_trail ignore: [ :projects_count, :votes_count ], on: [ :update, :destroy ]
  has_many :identities, class_name: "User::Identity", dependent: :destroy

  has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
  has_many :projects, through: :memberships
  has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :destroy
  has_many :shop_orders, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :reports, foreign_key: :reporter_id, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :ledger_entries, dependent: :destroy

  enum :verification_status, {
    needs_submission: "needs_submission",
    pending: "pending",
    verified: "verified",
    ineligible: "ineligible"
  }, default: :needs_submission, prefix: :verification

  validates :verification_status, presence: true
  validates :slack_id, presence: true, uniqueness: true
  validates :hcb_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  after_commit :handle_verification_eligibility_change, if: :should_check_verification_eligibility?

  ROLES = %i[super_admin admin fraud_dept project_certifier ysws_reviewer fulfillment_person].freeze

  ROLE_DESCRIPTIONS = {
    super_admin: "Can do everything an admin can, and also can assign other users admin",
    admin: "Can do everything except assign or remove admin",
    fraud_dept: "Can issue negative payouts, cancel grants & shop orders, but not reject or ban users; access to Blazer; access to read-only admin User w/o PII",
    project_certifier: "Approve/reject if project work meets Shipwright standards",
    ysws_reviewer: "Can approve/reject projects for YSWS DB",
    fulfillment_person: "Can approve/reject/on-hold shop orders, fulfill them, and see addresses; access to read-only admin User w/ pII"
  }.freeze

  def user_roles = roles&.map(&:to_sym) || []

  def has_role?(role_name) = user_roles.include?(role_name.to_sym)

  def add_role!(role_name)
    role_sym = role_name.to_sym
    raise ArgumentError, "Invalid role: #{role_name}" unless ROLES.include?(role_sym)
    update!(roles: (user_roles + [ role_sym.to_s ]).uniq) unless has_role?(role_sym)
  end

  def remove_role!(role_name)
    role_sym = role_name.to_sym
    update!(roles: user_roles.reject { |r| r == role_sym }.map(&:to_s)) if has_role?(role_sym)
  end

  # use me! i'm full of symbols!! disregard the foul tutorial_steps_completed, she lies
  def tutorial_steps = tutorial_steps_completed&.map(&:to_sym) || []

  def tutorial_step_completed?(slug) = tutorial_steps.include?(slug)

  def complete_tutorial_step!(slug)
    update!(tutorial_steps_completed: tutorial_steps + [ slug ]) unless tutorial_step_completed?(slug)
  end

  def revoke_tutorial_step!(slug)
    update!(tutorial_steps_completed: tutorial_steps - [ slug ]) if tutorial_step_completed?(slug)
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

  ROLES.each do |role_name|
    define_method "#{role_name}?" do
      has_role?(role_name)
    end

    define_method "make_#{role_name}!" do
      add_role!(role_name)
    end
  end

  def full_name
    [ first_name, last_name ].compact.join(" ").strip
  end

  def has_hackatime?
    identities.exists?(provider: "hackatime")
  end

  def has_identity_linked? = !verification_needs_submission?

  def identity_verified? = verification_verified?

  def eligible_for_shop? = identity_verified? && ysws_eligible?

  def should_reject_orders?
    verification_ineligible? || (identity_verified? && !ysws_eligible?)
  end

  def setup_complete?
    has_hackatime? && has_identity_linked?
  end

  def highest_role
    user_roles.min_by { |r| ROLES.index(r) }&.to_s&.titleize || "User"
  end

  def promote_to_big_leagues!
    add_role!(:super_admin)
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

  def balance = ledger_entries.sum(:amount)

  def ban!(reason: nil)
    update!(banned: true, banned_at: Time.current, banned_reason: reason)
    reject_pending_orders!(reason: reason || "User banned")
    soft_delete_projects!
  end

  def reject_pending_orders!(reason: "User banned")
    shop_orders.where(aasm_state: %w[pending awaiting_periodical_fulfillment]).find_each do |order|
      order.mark_rejected(reason)
      order.save!
    end
  end

  def soft_delete_projects!
    projects.find_each(&:soft_delete!)
  end

  def unban!
    update!(banned: false, banned_at: nil, banned_reason: nil)
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

  def avatar
    "http://cachet.dunkirk.sh/users/#{slack_id}/r"
  end

  def grant_email
    hcb_email.presence || email
  end

  def dm_user(message)
    SendSlackDmJob.perform_later(slack_id, message)
  end

  def has_commented?
    comments.exists?
  end
  def generate_api_key!
    PaperTrail.request(whodunnit: -> { id || "system" }) do
      update!(api_key: "ft_sk_" + SecureRandom.hex(20))
    end
  end

  private

  def should_check_verification_eligibility?
    saved_change_to_verification_status? || saved_change_to_ysws_eligible?
  end

  def handle_verification_eligibility_change
    if eligible_for_shop?
      Shop::ProcessVerifiedOrdersJob.perform_later(id)
    elsif should_reject_orders?
      reject_awaiting_verification_orders!
    end
  end

  def reject_awaiting_verification_orders!
    shop_orders.where(aasm_state: "awaiting_verification").find_each do |order|
      reason = if verification_ineligible?
                 "Identity verification marked as ineligible"
      else
                 "Not eligible for YSWS"
      end
      order.mark_rejected!(reason)
    end
  end
end
