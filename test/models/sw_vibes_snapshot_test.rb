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
require "test_helper"

class SwVibesSnapshotTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    snapshot = SwVibesSnapshot.new(
      recorded_date: Date.current,
      result: true,
      reason: "Things were good",
      payload: {}
    )
    assert snapshot.valid?, snapshot.errors.full_messages.join(", ")
  end

  test "invalid without recorded_date" do
    snapshot = SwVibesSnapshot.new(recorded_date: nil, result: true, reason: "Ok", payload: {})
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:recorded_date], "can't be blank"
  end

  test "invalid with duplicate recorded_date" do
    date = 1.week.ago.to_date
    SwVibesSnapshot.create!(recorded_date: date, result: true, reason: "Ok", payload: {})
    duplicate = SwVibesSnapshot.new(recorded_date: date, result: false, reason: "Bad", payload: {})
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:recorded_date], "has already been taken"
  end
end
