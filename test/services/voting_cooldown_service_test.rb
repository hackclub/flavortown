require "test_helper"

class VotingCooldownServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      email: "cooldown-#{SecureRandom.hex(4)}@example.com",
      display_name: "Cooldown User",
      slack_id: "U#{SecureRandom.hex(8)}"
    )
    @service = VotingCooldownService.new(@user)
  end

  test "apply! escalates stage from 0 to 4 and caps" do
    assert_difference -> { @user.reload.voting_lock_count }, 5 do
      5.times { @service.apply! }
    end
    assert_equal VotingCooldownService::MAX_STAGE, @user.reload.voting_cooldown_stage
  end

  test "apply! sets stage durations" do
    [
      [ 1, 30.minutes ],
      [ 2, 2.hours ],
      [ 3, 1.day ],
      [ 4, 1.week ]
    ].each do |stage, duration|
      @service.apply!
      @user.reload
      assert_equal stage, @user.voting_cooldown_stage
      assert_in_delta (Time.current + duration).to_i, @user.voting_cooldown_until.to_i, 10
    end
  end

  test "apply! marks existing votes suspicious" do
    project, event = create_project_with_ship_event
    vote = Vote.create!(
      user: @user,
      project: project,
      ship_event: event,
      reason: "Thorough review with clear rationale and balanced technical analysis for this project submission.",
      originality_score: 6,
      technical_score: 6,
      usability_score: 6,
      storytelling_score: 6,
      time_taken_to_vote: 30,
      demo_url_clicked: true,
      repo_url_clicked: true,
      suspicious: false
    )

    vote.update_column(:suspicious, false)
    @service.apply!

    assert vote.reload.suspicious?
  end

  test "active? checks cooldown boundary" do
    @user.update!(voting_cooldown_until: 5.minutes.from_now)
    assert @service.active?

    @user.update!(voting_cooldown_until: 1.minute.ago)
    refute @service.active?
  end

  test "clear! clears cooldown" do
    @user.update!(voting_cooldown_until: 5.minutes.from_now)
    @service.clear!
    assert_nil @user.reload.voting_cooldown_until
  end

  test "record_clean_vote! updates last_clean_vote_at" do
    @service.record_clean_vote!
    assert_in_delta Time.current.to_i, @user.reload.last_clean_vote_at.to_i, 5
  end

  test "record_clean_vote! decays stage after cooldown expired for 7 days" do
    @user.update!(
      voting_cooldown_stage: 2,
      voting_cooldown_until: VotingCooldownService::DECAY_PERIOD.ago - 1.hour,
      last_clean_vote_at: Time.current
    )

    @service.record_clean_vote!
    assert_equal 1, @user.reload.voting_cooldown_stage
  end

  test "record_clean_vote! does not decay when cooldown is active" do
    @user.update!(
      voting_cooldown_stage: 2,
      voting_cooldown_until: 1.hour.from_now,
      last_clean_vote_at: Time.current
    )

    @service.record_clean_vote!
    assert_equal 2, @user.reload.voting_cooldown_stage
  end

  test "record_clean_vote! does not decay when cooldown expiry is too recent" do
    @user.update!(
      voting_cooldown_stage: 2,
      voting_cooldown_until: 1.day.ago,
      last_clean_vote_at: Time.current
    )

    @service.record_clean_vote!
    assert_equal 2, @user.reload.voting_cooldown_stage
  end

  test "record_clean_vote! decays when cooldown was manually cleared and clean period elapsed" do
    @user.update!(
      voting_cooldown_stage: 2,
      voting_cooldown_until: nil,
      last_clean_vote_at: VotingCooldownService::DECAY_PERIOD.ago + 1.hour
    )

    @service.record_clean_vote!
    assert_equal 1, @user.reload.voting_cooldown_stage
  end

  private

  def create_project_with_ship_event
    owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      display_name: "Owner",
      slack_id: "U#{SecureRandom.hex(8)}"
    )
    project = Project.create!(title: "Cooldown Project #{SecureRandom.hex(4)}")
    Project::Membership.create!(project:, user: owner)
    event = Post::ShipEvent.create!(body: "Ship #{SecureRandom.hex(2)}")
    Post.create!(project:, user: owner, postable: event)
    [ project, event ]
  end
end
