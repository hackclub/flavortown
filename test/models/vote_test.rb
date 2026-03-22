# == Schema Information
#
# Table name: votes
#
#  id                 :bigint           not null, primary key
#  demo_url_clicked   :boolean          default(FALSE)
#  originality_score  :integer
#  reason             :text
#  repo_url_clicked   :boolean          default(FALSE)
#  storytelling_score :integer
#  suspicious         :boolean          default(FALSE), not null
#  technical_score    :integer
#  time_taken_to_vote :integer
#  usability_score    :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#  ship_event_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_votes_on_project_id                 (project_id)
#  index_votes_on_ship_event_id              (ship_event_id)
#  index_votes_on_suspicious_and_created_at  (suspicious,created_at)
#  index_votes_on_user_id                    (user_id)
#  index_votes_on_user_id_and_ship_event_id  (user_id,ship_event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (ship_event_id => post_ship_events.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class VoteTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      email: "vote-user-#{SecureRandom.hex(4)}@example.com",
      display_name: "Vote User",
      slack_id: "U#{SecureRandom.hex(8)}"
    )
    @owner = User.create!(
      email: "vote-owner-#{SecureRandom.hex(4)}@example.com",
      display_name: "Owner",
      slack_id: "U#{SecureRandom.hex(8)}"
    )
    @project = Project.create!(title: "Vote Test Project #{SecureRandom.hex(3)}")
    Project::Membership.create!(project: @project, user: @owner)
    @ship_event = Post::ShipEvent.create!(body: "Ship Event #{SecureRandom.hex(2)}")
    Post.create!(project: @project, user: @owner, postable: @ship_event)
  end

  test "create records clean vote timestamp for non-suspicious vote" do
    @user.update!(
      voting_cooldown_stage: 2,
      voting_cooldown_until: VotingCooldownService::DECAY_PERIOD.ago - 1.hour,
      last_clean_vote_at: nil
    )

    vote = create_vote_for(@user)

    refute vote.suspicious?
    assert @user.reload.last_clean_vote_at.present?
    assert_equal 1, @user.voting_cooldown_stage
  end

  test "create does not record clean vote for suspicious vote" do
    vote = create_vote_for(@user, time_taken_to_vote: 1, demo_url_clicked: false, repo_url_clicked: false)

    assert vote.suspicious?
    assert_nil @user.reload.last_clean_vote_at
  end

  private

  def create_vote_for(user, time_taken_to_vote: 30, demo_url_clicked: true, repo_url_clicked: true)
    Vote.create!(
      user: user,
      project: @project,
      ship_event: @ship_event,
      reason: "Detailed review covering implementation tradeoffs, usability, and clear technical reasoning across the project.",
      originality_score: 6,
      technical_score: 6,
      usability_score: 6,
      storytelling_score: 6,
      time_taken_to_vote: time_taken_to_vote,
      demo_url_clicked: demo_url_clicked,
      repo_url_clicked: repo_url_clicked
    )
  end
end
