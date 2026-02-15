require "securerandom"
require "test_helper"

class VoteMatchmakerTest < ActiveSupport::TestCase
  test "should prioritize melon's projects" do
    # Create users
    user = users(:one)
    melon = User.create!(username: "melon", email: "melon-#{SecureRandom.uuid}@example.com", password: SecureRandom.uuid)
    other_user = users(:two)

    # Create projects
    other_project = Project.create!(title: "Other Project")
    other_project.users << other_user
    melon_project = Project.create!(title: "Melon Project")
    melon_project.users << melon

    # Create ship events
    other_post = Post.create!(project: other_project, user: other_user, postable: Post::ShipEvent.new(body: "other ship"))
    other_ship_event = other_post.postable
    other_ship_event.update!(certification_status: "approved")


    melon_post = Post.create!(project: melon_project, user: melon, postable: Post::ShipEvent.new(body: "melon ship"))
    melon_ship_event = melon_post.postable
    melon_ship_event.update!(certification_status: "approved")


    # Run the matchmaker multiple times to ensure melon's project is always first
    10.times do
      matchmaker = VoteMatchmaker.new(user)
      next_ship_event = matchmaker.next_ship_event

      # if melon's project still needs votes, it should be returned
      if melon_ship_event.votes_count < Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT
        assert_equal melon_project, next_ship_event.project, "Melon's project should be prioritized"
        # add a vote to melon's project to simulate it getting votes
        Vote.create!(user: user, project: melon_project, ship_event: melon_ship_event, originality_score: 5, technical_score: 5, usability_score: 5, storytelling_score: 5)
      else
        assert_equal other_project, next_ship_event.project, "Other project should be returned after melon's project is fully voted"
      end
    end
  end
end
