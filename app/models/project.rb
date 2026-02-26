# == Schema Information
#
# Table name: projects
#
#  id                   :bigint           not null, primary key
#  ai_declaration       :text
#  deleted_at           :datetime
#  demo_url             :text
#  description          :text
#  devlogs_count        :integer          default(0), not null
#  duration_seconds     :integer          default(0), not null
#  marked_fire_at       :datetime
#  memberships_count    :integer          default(0), not null
#  project_categories   :string           default([]), is an Array
#  project_type         :string
#  readme_url           :text
#  repo_url             :text
#  shadow_banned        :boolean          default(FALSE), not null
#  shadow_banned_at     :datetime
#  shadow_banned_reason :text
#  ship_status          :string           default("draft")
#  shipped_at           :datetime
#  synced_at            :datetime
#  title                :string           not null
#  tutorial             :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  fire_letter_id       :string
#  marked_fire_by_id    :bigint
#
# Indexes
#
#  index_projects_on_deleted_at         (deleted_at)
#  index_projects_on_marked_fire_by_id  (marked_fire_by_id)
#  index_projects_on_shadow_banned      (shadow_banned)
#
# Foreign Keys
#
#  fk_rails_...  (marked_fire_by_id => users.id)
#
class Project < ApplicationRecord
  include AASM
  include SoftDeletable

  SPACE_THEMED_PREFIX = "Space Themed:".freeze

  has_paper_trail only: %i[shadow_banned shadow_banned_at shadow_banned_reason deleted_at]

  has_recommended :projects # more projects like this...

  has_many :sidequest_entries, dependent: :destroy
  has_many :sidequests, through: :sidequest_entries

  after_create :notify_slack_channel

  ACCEPTED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
  MAX_BANNER_SIZE = 10.megabytes

  AVAILABLE_CATEGORIES = [
    "CLI", "Cargo", "Web App", "Chat Bot", "Extension",
    "Desktop App (Windows)", "Desktop App (Linux)", "Desktop App (macOS)",
    "Minecraft Mods", "Hardware", "Android App", "iOS App", "Other"
  ].freeze

  scope :excluding_member, ->(user) {
    user ? where.not(id: user.projects) : all
  }
  scope :fire, -> { where.not(marked_fire_at: nil) }
  scope :excluding_shadow_banned, -> {
    where(shadow_banned: false)
      .joins(:memberships)
      .joins("INNER JOIN users ON users.id = project_memberships.user_id")
      .where(users: { shadow_banned: false })
      .distinct
  }
  scope :visible_to, ->(viewer) {
    if viewer&.shadow_banned?
      # Shadow-banned users see all projects (so they don't know they're banned)
      all
    elsif viewer
      # Regular users see non-shadow-banned projects + their own projects
      left_joins(memberships: :user)
        .where(shadow_banned: false)
        .where(memberships: { users: { shadow_banned: false } })
        .or(left_joins(memberships: :user).where(memberships: { user_id: viewer.id }))
        .distinct
    else
      excluding_shadow_banned
    end
  }

  belongs_to :marked_fire_by, class_name: "User", optional: true

  has_many :memberships, class_name: "Project::Membership", dependent: :destroy
  has_many :users, through: :memberships
  has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :nullify
  has_many :posts, dependent: :destroy
  has_many :devlog_posts, -> { where(postable_type: "Post::Devlog").order(created_at: :desc) }, class_name: "Post"
  has_many :devlogs, through: :devlog_posts, source: :postable, source_type: "Post::Devlog"
  has_many :ship_event_posts, -> { where(postable_type: "Post::ShipEvent").order(created_at: :desc) }, class_name: "Post"
  has_many :ship_events, through: :ship_event_posts, source: :postable, source_type: "Post::ShipEvent"
  has_many :git_commit_posts, -> { where(postable_type: "Post::GitCommit").order(created_at: :desc) }, class_name: "Post"
  has_many :votes, dependent: :destroy
  has_many :reports, class_name: "Project::Report", dependent: :destroy
  has_many :project_follows, dependent: :destroy
  has_many :followers, through: :project_follows, source: :user
  # needs to be implemented
  has_one_attached :demo_video

  # https://github.com/rails/rails/pull/39135
  has_one_attached :banner do |attachable|
    # using resize_to_limit to preserve aspect ratio without cropping
    # we're preprocessing them because its likely going to be used

    # for explore and projects#index
    attachable.variant :card,
                       resize_to_limit: [ 1600, 900 ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }

    #   attachable.variant :not_sure,
    #     resize_to_limit: [ 1200, 630 ],
    #     format: :webp,
    #     saver: { strip: true, quality: 75 }

    # for voting
    attachable.variant :thumb,
                       resize_to_limit: [ 400, 210 ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }
  end

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 1_000 }, allow_blank: true
  validates :ai_declaration, length: { maximum: 1_000 }, allow_blank: true
  validates :demo_url, :repo_url, :readme_url,
            length: { maximum: 2_048 },
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
            allow_blank: true
  validates :banner,
            content_type: { in: ACCEPTED_CONTENT_TYPES, spoofing_protection: true },
            size: { less_than: MAX_BANNER_SIZE, message: "is too large (max 10 MB)" },
            processable_file: true
  validate :validate_project_categories

  def validate_project_categories
    return if project_categories.blank?

    invalid_types = project_categories - AVAILABLE_CATEGORIES
    if invalid_types.any?
      errors.add(:project_categories, "contains invalid types: #{invalid_types.join(', ')}")
    end
  end

  def validate_repo_cloneable
    return false if repo_url.blank?

    GitRepoService.is_cloneable? repo_url
  end

  def validate_repo_url_format
    return true if repo_url.blank?

    # Check if repo_url ends with .git or contains /main/tree
    repo_url.strip!
    if repo_url.end_with?(".git") || repo_url.include?("/main/tree")
      errors.add(:repo_url, "should not end with .git or contain /main/tree. Please use the root GitHub repository URL.")
      return false
    end
    true
  end

  def calculate_duration_seconds
    posts.of_devlogs(join: true).where(post_devlogs: { deleted_at: nil }).sum("post_devlogs.duration_seconds")
  end

  def recalculate_duration_seconds!
    update_column(:duration_seconds, calculate_duration_seconds)
  end

  # this can probaby be better?
  def soft_delete!(force: false)
    if !force && shipped?
      errors.add(:base, "Cannot delete a project that has been shipped")
      raise ActiveRecord::RecordInvalid.new(self)
    end
    update!(deleted_at: Time.current)
  end

  def shipped?
    shipped_at.present? || !draft?
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def space_themed?
    description.to_s.lstrip.start_with?(SPACE_THEMED_PREFIX)
  end

  def description_without_space_theme_prefix
    description.to_s.sub(/\A\s*#{Regexp.escape(SPACE_THEMED_PREFIX)}\s*/, "")
  end

  def display_description
    description_without_space_theme_prefix
  end

  def hackatime_keys
    hackatime_projects.pluck(:name)
  end

  def total_hackatime_hours
    return 0 if hackatime_projects.empty?

    owner = memberships.owner.first&.user
    return 0 unless owner

    result = owner.try_sync_hackatime_data!
    return 0 unless result

    project_times = result[:projects]
    total_seconds = hackatime_projects.sum { |hp| project_times[hp.name].to_i }
    (total_seconds / 3600.0).round(1)
  end

  def hackatime_projects_with_time
    owner = memberships.owner.first&.user
    return [] unless owner

    result = owner.try_sync_hackatime_data!
    return [] unless result

    project_times = result[:projects]
    hackatime_projects.map do |hp|
      {
        name: hp.name,
        hours: (project_times[hp.name].to_i / 3600.0).round(1)
      }
    end
  end

  aasm column: :ship_status do
    state :draft, initial: true
    state :submitted
    state :under_review
    state :approved
    state :rejected

    event :submit_for_review do
      transitions from: [ :draft, :submitted, :under_review, :approved, :rejected ], to: :submitted, guard: :shippable?
      after do
        self.shipped_at = Time.current
      end
    end

    event :start_review do
      transitions from: :submitted, to: :under_review
    end

    event :approve do
      transitions from: :under_review, to: :approved
    end

    event :reject do
      transitions from: :under_review, to: :rejected
    end
  end

  def shipping_requirements
    [
      { key: :not_shadow_banned, label: "This project has been flagged by moderation and cannot ship", passed: !shadow_banned? },
      { key: :demo_url, label: "Add a demo link so anyone can try your project", passed: demo_url.present? },
      { key: :repo_url, label: "Add a public GitHub URL with your source code", passed: repo_url.present? },
      { key: :repo_url_format, label: "Use the root GitHub repository URL (no .git or /main/tree)", passed: validate_repo_url_format },
      { key: :repo_cloneable, label: "Make your GitHub repo publicly cloneable", passed: validate_repo_cloneable },
      { key: :readme_url, label: "Add a README URL to your project", passed: readme_url.present? },
      { key: :description, label: "Add a description for your project", passed: description.present? },
      { key: :banner, label: "Upload a banner image for your project", passed: banner.attached? },
      { key: :devlog, label: "Post at least one devlog since your last ship", passed: has_devlog_since_last_ship? },
      { key: :payout, label: "Wait for your previous ship's to get a payout", passed: previous_ship_event_has_payout? },
      { key: :vote_balance, label: "Your vote balance is negative", passed: memberships.owner.first&.user&.vote_balance.to_i >= 0 },
      { key: :project_isnt_rejected, label: "Your project is not rejected!", passed: last_ship_event&.certification_status != "rejected" },
      { key: :project_has_more_then_10s, label: "Your ship event has actual time attached to it! (all devlogs have more then 10s)", passed: duration_seconds > 10 }
    ]
  end

  def shippable? = shipping_requirements.all? { |r| r[:passed] }
  def ship_blocking_errors = shipping_requirements.reject { |r| r[:passed] }.map { |r| r[:label] }

  def last_ship_event
    ship_events.first
  end

  def fire?
    marked_fire_at.present?
  end

  def mark_fire!(user)
    update!(marked_fire_at: Time.current, marked_fire_by: user)
  end

  def unmark_fire!
    update!(marked_fire_at: nil, marked_fire_by: nil)
  end

  def shadow_ban!(reason: nil)
    update!(shadow_banned: true, shadow_banned_at: Time.current, shadow_banned_reason: reason)
  end

  def unshadow_ban!
    update!(shadow_banned: false, shadow_banned_at: nil, shadow_banned_reason: nil)
  end

  def readme_is_raw_github_url?
    return false if readme_url.blank?

    begin
      uri = URI.parse(readme_url)
    rescue URI::InvalidURIError
      return false
    end

    return false unless uri.host == "raw.githubusercontent.com"

    /https:\/\/raw\.githubusercontent\.com\/[^\/]+\/[^\/]+\/[^\/]+\/.*README.*\.md/i.match?(uri.to_s)
  end

  private

  def has_devlog_since_last_ship?
    return true if last_ship_event.nil?
    devlog_posts.where("posts.created_at > ?", last_ship_event.created_at).exists?
  end

  def previous_ship_event_has_payout?
    return true if last_ship_event.nil?
    last_ship_event.payout.present? && last_ship_event.payout > 0
  end

  def notify_slack_channel
    PostCreationToSlackJob.perform_later(self)
  end
end
