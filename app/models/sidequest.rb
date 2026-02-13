# == Schema Information
#
# Table name: sidequests
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

  def to_param
    slug
  end

  # Ensures Challenger and Extensions sidequests exist (e.g. when visiting /sidequests without running seeds).
  def self.ensure_default_sidequests!
    find_or_create_by!(slug: "extension") do |sq|
      sq.title = "Extensions"
      sq.description = "Unlock a Chrome Developer License in the shop! Must have a GitHub release with a .crx file to qualify."
      sq.expires_at = Date.new(2026, 2, 20)
    end
    find_or_create_by!(slug: "challenger") do |sq|
      sq.title = "Challenger Center"
      sq.description = "Ship a space-related project by March 31! Submit it to this sidequest to qualify for space-themed prizes in the shop."
    end
  end
end
