require "test_helper"

class CookieTransfersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @sender = users(:one)
    @recipient = users(:two)

    @sender.ledger_entries.create!(
      amount: 100,
      reason: "Test grant",
      ledgerable: @sender
    )

    Flipper.enable(:cookie_transfers, @sender)
  end

  def login_as(user)
    post "/auth/hack_club/callback", params: {}, env: { "omniauth.auth" => mock_auth(user) }
  end

  def mock_auth(user)
    OmniAuth::AuthHash.new({
      provider: "hack_club",
      uid: user.slack_id || "test_uid",
      info: {
        email: user.email,
        name: user.display_name
      }
    })
  end

  test "redirects to root when feature is disabled" do
    Flipper.disable(:cookie_transfers, @sender)

    get new_cookie_transfer_path
    assert_redirected_to root_path
  end

  test "redirects to root when not logged in" do
    get new_cookie_transfer_path
    assert_redirected_to root_path
  end
end
