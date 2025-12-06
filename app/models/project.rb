# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  demo_url          :text
#  description       :text
#  memberships_count :integer          default(0), not null
#  readme_url        :text
#  repo_url          :text
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class Project < ApplicationRecord

    # TODO: reflect the allowed content types in the html accept
    ACCEPTED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
    MAX_BANNER_SIZE = 10.megabytes

    has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
    has_many :users, through: :memberships
    has_many :hackatime_projects, class_name: "User::HackatimeProject", dependent: :nullify
    has_many :posts, dependent: :destroy
    # prolly countercache it
    has_many :devlogs, -> { where(postable_type: "Post::Devlog") }, class_name: "Post"
    has_many :votes, dependent: :destroy

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

    def hackatime_keys
        hackatime_projects.pluck(:name)
    end
end
