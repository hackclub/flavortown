# == Schema Information
#
# Table name: flavortime_sessions
#
#  id                     :bigint           not null, primary key
#  app_version            :string
#  discord_shared_seconds :integer          default(0), not null
#  ended_at               :datetime
#  ended_reason           :string
#  expires_at             :datetime         not null
#  last_heartbeat_at      :datetime         not null
#  platform               :string
#  session_id             :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :bigint           not null
#
# Indexes
#
#  index_flavortime_sessions_on_expires_at              (expires_at)
#  index_flavortime_sessions_on_session_id              (session_id) UNIQUE
#  index_flavortime_sessions_on_user_id                 (user_id)
#  index_flavortime_sessions_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class FlavortimeSession < ApplicationRecord
  SESSION_TTL = 2.minutes
  END_REASON_TIMED_OUT = "timed_out"
  END_REASON_VOLUNTARY_CLOSE = "voluntary_close"

  belongs_to :user

  validates :session_id, uniqueness: true, allow_nil: true
  validates :last_heartbeat_at, :expires_at, presence: true
  validates :discord_shared_seconds, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :active, -> {
    where.not(session_id: nil).where("expires_at > ?", Time.current)
  }

  scope :within, ->(from_time, to_time) {
    scope = all
    scope = scope.where("created_at >= ?", from_time) if from_time.present?
    scope = scope.where("created_at <= ?", to_time) if to_time.present?
    scope
  }

  def self.cleanup_expired!(now = Time.current)
    where.not(session_id: nil)
      .where("expires_at <= ?", now)
      .update_all(session_id: nil, ended_at: now, ended_reason: END_REASON_TIMED_OUT, updated_at: now)
  end

  def self.active_users_count
    active.select(:user_id).distinct.count
  end

  def record_heartbeat!(reported_shared_seconds, platform: nil, app_version: nil, now: Time.current)
    normalized_seconds = [ reported_shared_seconds.to_i, 0 ].max

    attrs = {
      last_heartbeat_at: now,
      expires_at: now + SESSION_TTL,
      ended_at: nil,
      ended_reason: nil,
      discord_shared_seconds: [ discord_shared_seconds, normalized_seconds ].max
    }
    attrs[:platform] = platform if platform.present?
    attrs[:app_version] = app_version if app_version.present?

    update!(attrs)
  end

  def close!(reported_shared_seconds, platform: nil, app_version: nil, now: Time.current)
    normalized_seconds = [ reported_shared_seconds.to_i, 0 ].max

    attrs = {
      session_id: nil,
      ended_at: now,
      expires_at: now,
      ended_reason: END_REASON_VOLUNTARY_CLOSE,
      discord_shared_seconds: [ discord_shared_seconds, normalized_seconds ].max
    }
    attrs[:platform] = platform if platform.present?
    attrs[:app_version] = app_version if app_version.present?

    update!(attrs)
  end

  def self.start_for!(user, session_id:, platform: nil, app_version: nil, now: Time.current)
    create!(
      user: user,
      session_id: session_id,
      platform: platform.presence,
      app_version: app_version.presence,
      last_heartbeat_at: now,
      expires_at: now + SESSION_TTL,
      discord_shared_seconds: 0
    )
  end
end
