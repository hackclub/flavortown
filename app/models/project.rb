# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  deleted_at        :datetime
#  demo_url          :text
#  description       :text
#  memberships_count :integer          default(0), not null
#  project_type      :string
#  readme_url        :text
#  repo_url          :text
#  ship_status       :string           default("draft")
#  shipped_at        :datetime
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_projects_on_deleted_at  (deleted_at)
#
class Project < ApplicationRecord
    include AASM

    # TODO: reflect the allowed content types in the html accept
    ACCEPTED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
    MAX_BANNER_SIZE = 10.megabytes

    scope :kept, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }

    default_scope { kept }

    has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
    has_many :users, through: :memberships
    has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :nullify
    has_many :posts, dependent: :destroy
    # prolly countercache it
    has_many :devlogs, -> { where(postable_type: "Post::Devlog") }, class_name: "Post"
    has_many :votes, dependent: :destroy
    has_many :reports, dependent: :destroy

    has_one_attached :demo_video
    # https://github.com/rails/rails/pull/39135
    has_one_attached :banner do |attachable|
        # using resize_to_fill instead of resize_to_limit because consistency. might change it to resize_to_limit
        # we're preprocessing them because its likely going to be used

        # for explore and projects#index
        attachable.variant :card,
                           resize_to_fill: [ 1600, 900 ],
                           format: :webp,
                           preprocessed: true,
                           saver: { strip: true, quality: 75 }

        #   attachable.variant :not_sure,
        #     resize_to_fill: [ 1200, 630 ],
        #     format: :webp,
        #     saver: { strip: true, quality: 75 }

        # for voting
        attachable.variant :thumb,
                           resize_to_fill: [ 400, 210 ],
                           format: :webp,
                           preprocessed: true,
                           saver: { strip: true, quality: 75 }
    end

    validates :title, presence: true, length: { maximum: 120 }
    validates :description, length: { maximum: 1_000 }, allow_blank: true
    validates :demo_url, :repo_url, :readme_url,
              length: { maximum: 2_048 },
              format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
              allow_blank: true
    validates :banner,
              content_type: { in: ACCEPTED_CONTENT_TYPES, spoofing_protection: true },
              size: { less_than: MAX_BANNER_SIZE, message: "is too large (max 10 MB)" },
              processable_file: true

    scope :votable_by, ->(user) {
        where.not(id: user.projects.select(:id))
        .where.not(id: user.votes.select(:project_id))
    }

    def time
        total_seconds = Post::Devlog.where(id: posts.where(postable_type: "Post::Devlog").select("postable_id::bigint")).sum(:duration_seconds) || 0
        total_hours = total_seconds / 3600.0
        hours = total_hours.to_i
        minutes = ((total_hours - hours) * 60).to_i

        OpenStruct.new(hours: hours, minutes: minutes)
    end

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def restore!
      update!(deleted_at: nil)
    end

    def deleted?
      deleted_at.present?
    end
    def hackatime_keys
        hackatime_projects.pluck(:name)
    end

    def total_hackatime_hours
        return 0 if hackatime_projects.empty?

        owner = memberships.owner.first&.user
        return 0 unless owner

        hackatime_identity = owner.identities.find_by(provider: "hackatime")
        return 0 unless hackatime_identity

        project_times = HackatimeService.fetch_user_projects_with_time(hackatime_identity.uid, user: owner)
        total_seconds = hackatime_projects.sum { |hp| project_times[hp.name].to_i }
        (total_seconds / 3600.0).round(1)
    end

    def hackatime_projects_with_time
        owner = memberships.owner.first&.user
        return [] unless owner

        hackatime_identity = owner.identities.find_by(provider: "hackatime")
        return [] unless hackatime_identity

        project_times = HackatimeService.fetch_user_projects_with_time(hackatime_identity.uid, user: owner)
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
            transitions from: [ :draft, :submitted, :under_review, :approved, :rejected ], to: :submitted, guard: :can_ship_again?
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

    def can_ship_again?
        return true if draft?
        has_devlog_since_last_ship?
    end

    def has_devlog_since_last_ship?
        last_ship = last_ship_event
        return true if last_ship.nil?

        devlogs.where("created_at > ?", last_ship.created_at).exists?
    end

    def last_ship_event
        posts.where(postable_type: "Post::ShipEvent").order(created_at: :desc).first
    end

    def shippable?
        demo_url.present? &&
        repo_url.present? &&
        banner.attached? &&
        description.present? &&
        devlogs.any?
    end

    def shipping_validations
        [
            { key: :demo_url, label: "You have an experienceable link (a URL where anyone can try your project now)", passed: demo_url.present? },
            { key: :repo_url, label: "You have a public GitHub URL with all source code", passed: repo_url.present? },
            { key: :screenshot, label: "You have a screenshot of your project", passed: banner.attached? },
            { key: :devlogs, label: "You have at least one devlog", passed: devlogs.any? }
        ]
    end
end
