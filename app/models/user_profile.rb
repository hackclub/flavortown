# == Schema Information
#
# Table name: user_profiles
#
#  id         :bigint           not null, primary key
#  bio        :text
#  custom_css :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_profiles_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class UserProfile < ApplicationRecord
  belongs_to :user

  validates :bio, length: { maximum: 1000 }, allow_blank: true
  validates :custom_css, length: { maximum: 10_000 }, allow_blank: true
  validate :check_xss

  before_save :clean_css

  def check_xss
    return if custom_css.blank?

    css = custom_css.downcase
    bad = [ "</style>", "<script", "javascript:", "@import", "/*</style>", "*/<", "/*<" ]

    bad.each do |pattern|
      if css.include?(pattern)
        errors.add(:custom_css, "— that ain't gonna work, chef")
        return
      end
    end

    if css.match?(/\/\*.*<.*\*\//m) || css.match?(/<[^>]*>/)
      errors.add(:base, "— that ain't gonna work, chef")
    end
  end

  def clean_css
    return if custom_css.blank?

    self.custom_css = custom_css
      .gsub(/\/\*.*?<.*?\*\//m, "")
      .gsub(/<[^>]*>/, "")
      .strip
  end
end
