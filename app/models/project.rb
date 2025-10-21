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

    has_many :memberships, class_name:  "Project::Membership", dependent: :destroy
    has_many :users, through: :memberships

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
    validates :banner,
              content_type: { in: ACCEPTED_CONTENT_TYPES, spoofing_protection: true },
              size: { less_than: 10.megabytes, message: "is too large (max 10 MB)" },
              processable_file: true
end
