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
end
