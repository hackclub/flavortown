require "test_helper"

class Projects::ShipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      slack_id: "U#{SecureRandom.hex(8)}",
      email: "ship-test-#{SecureRandom.hex(4)}@example.com",
      display_name: "Ship Tester",
      verification_status: "verified",
      ysws_eligible: true,
      vote_balance: 15
    )
    @project = Project.create!(
      title: "Test Ship Project #{SecureRandom.hex(4)}",
      description: "A test project description",
      repo_url: "https://github.com/test/repo",
      demo_url: "https://demo.example.com",
      readme_url: "https://raw.githubusercontent.com/test/repo/main/README.md",
      duration_seconds: 3600
    )
    @project.memberships.create!(user: @user, role: :owner)
    Flipper.enable(:shipping)
  end

  teardown do
    Flipper.disable(:shipping)
  end

  test "create saves review_instructions on the ship event" do
    sign_in @user
    Project.stub(:find, @project) do
      @project.stub(:shippable?, true) do
        assert_difference "Post::ShipEvent.count", 1 do
          post project_ships_path(@project),
            params: { ship_update: "My ship update", review_instructions: "Run npm test to verify" }
        end
        assert_equal "Run npm test to verify", Post::ShipEvent.last.review_instructions
        assert_redirected_to @project
      end
    end
  end

  test "create trims whitespace from review_instructions" do
    sign_in @user
    Project.stub(:find, @project) do
      @project.stub(:shippable?, true) do
        post project_ships_path(@project),
          params: { ship_update: "My ship update", review_instructions: "  trim me  " }
        assert_equal "trim me", Post::ShipEvent.last.review_instructions
      end
    end
  end

  test "create stores nil for blank review_instructions" do
    sign_in @user
    Project.stub(:find, @project) do
      @project.stub(:shippable?, true) do
        post project_ships_path(@project),
          params: { ship_update: "My ship update", review_instructions: "   " }
        assert_nil Post::ShipEvent.last.review_instructions
      end
    end
  end

  test "create stores nil when review_instructions is omitted" do
    sign_in @user
    Project.stub(:find, @project) do
      @project.stub(:shippable?, true) do
        post project_ships_path(@project),
          params: { ship_update: "My ship update" }
        assert_nil Post::ShipEvent.last.review_instructions
      end
    end
  end
end
