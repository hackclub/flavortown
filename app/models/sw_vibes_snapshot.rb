# == Schema Information
#
# Table name: sw_vibes_snapshots
#
#  id            :bigint           not null, primary key
#  payload       :jsonb
#  reason        :text
#  recorded_date :date             not null
#  result        :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_sw_vibes_snapshots_on_recorded_date  (recorded_date) UNIQUE
#
class SwVibesSnapshot < ApplicationRecord
  has_paper_trail

  validates :recorded_date, presence: true, uniqueness: true
end
