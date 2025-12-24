# == Schema Information
#
# Table name: funnel_events
#
#  id         :bigint           not null, primary key
#  email      :string
#  event_name :string           not null
#  properties :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_funnel_events_on_created_at                 (created_at)
#  index_funnel_events_on_email                      (email)
#  index_funnel_events_on_event_name                 (event_name)
#  index_funnel_events_on_event_name_and_created_at  (event_name,created_at)
#  index_funnel_events_on_user_id                    (user_id)
#
class FunnelEvent < ApplicationRecord
  belongs_to :user, optional: true

  validates :event_name, presence: true
  validates :email, presence: true, if: -> { user_id.blank? }
  validates :user_id, presence: true, if: -> { email.blank? }
  validate :email_format, if: -> { email.present? }

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_email, ->(email) { where(email: normalize_email_for_query(email)) }
  scope :by_event, ->(name) { where(event_name: name) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pre_signup, -> { where(user_id: nil) }
  scope :post_signup, -> { where.not(user_id: nil) }

  private

  def email_format
    return if email.match?(URI::MailTo::EMAIL_REGEXP)

    errors.add(:email, "must be a valid email address")
  end

  def self.normalize_email_for_query(email)
    email.to_s.strip.downcase
  end
end
