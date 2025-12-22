# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  api_key                     :string
#  banned                      :boolean          default(FALSE), not null
#  banned_at                   :datetime
#  banned_reason               :text
#  cookie_clicks               :integer          default(0), not null
#  display_name                :string
#  email                       :string
#  first_name                  :string
#  granted_roles               :string           default([]), not null, is an Array
#  has_gotten_free_stickers    :boolean          default(FALSE)
#  has_pending_achievements    :boolean          default(FALSE), not null
#  hcb_email                   :string
#  introduction_posted_at      :datetime
#  last_name                   :string
#  leaderboard_optin           :boolean          default(FALSE), not null
#  magic_link_token            :string
#  magic_link_token_expires_at :datetime
#  projects_count              :integer
#  ref                         :string
#  regions                     :string           default([]), is an Array
#  send_votes_to_slack         :boolean          default(FALSE), not null
#  session_token               :string
#  shop_region                 :enum
#  slack_balance_notifications :boolean          default(FALSE), not null
#  synced_at                   :datetime
#  tutorial_steps_completed    :string           default([]), is an Array
#  verification_status         :string           default("needs_submission"), not null
#  vote_anonymously            :boolean          default(FALSE), not null
#  votes_count                 :integer
#  ysws_eligible               :boolean          default(FALSE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  slack_id                    :string
#
# Indexes
#
#  index_users_on_email             (email)
#  index_users_on_magic_link_token  (magic_link_token) UNIQUE
#  index_users_on_session_token     (session_token) UNIQUE
#  index_users_on_slack_id          (slack_id) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "grant_email returns hcb_email when present" do
    user = users(:one)
    user.hcb_email = "hcb@example.com"
    assert_equal "hcb@example.com", user.grant_email
  end

  test "grant_email falls back to email when hcb_email is nil" do
    user = users(:one)
    user.hcb_email = nil
    assert_equal user.email, user.grant_email
  end

  test "grant_email falls back to email when hcb_email is blank" do
    user = users(:one)
    user.hcb_email = ""
    assert_equal user.email, user.grant_email
  end

  test "hcb_email validates email format" do
    user = users(:one)
    user.hcb_email = "not-an-email"
    assert_not user.valid?
    assert_includes user.errors[:hcb_email], "is invalid"
  end

  test "hcb_email allows valid email format" do
    user = users(:one)
    user.hcb_email = "valid@example.com"
    assert user.valid?
  end

  test "hcb_email allows blank value" do
    user = users(:one)
    user.hcb_email = ""
    assert user.valid?
  end
end
