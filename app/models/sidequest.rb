# == Schema Information
#
# Table name: sidequests
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  description        :string
#  expires_at         :datetime
#  external_page_link :string
#  slug               :string           not null
#  title              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_sidequests_on_slug  (slug) UNIQUE
#
class Sidequest < ApplicationRecord
  has_many :sidequest_entries, dependent: :destroy
  has_many :projects, through: :sidequest_entries

  validates :slug, presence: true, uniqueness: true
  validates :title, presence: true

  scope :active, ->(date: Date.current) { where("expires_at IS NULL OR expires_at >= ?", date) }
  scope :expired, ->(date: Date.current) { where.not("expires_at IS NULL OR expires_at >= ?", date) }
  scope :with_approved_count, -> {
    left_joins(:sidequest_entries)
      .select("sidequests.*, COUNT(sidequest_entries.id) FILTER (WHERE sidequest_entries.aasm_state = 'approved') AS approved_count")
      .group("sidequests.id")
  }

  def to_param
    slug
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def to_partial_path
    "sidequests/#{slug}"
  end
end
