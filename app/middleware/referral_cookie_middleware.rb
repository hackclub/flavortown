class ReferralCookieMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    if (ref = request.params["ref"]).present? && ref.length <= 64
      status, headers, response = @app.call(env)

      Rack::Utils.set_cookie_header!(
        headers,
        "referral_code",
        {
          value: ref,
          path: "/",
          max_age: 30.days.to_i,
          same_site: :lax
        }
      )

      [ status, headers, response ]
    else
      @app.call(env)
    end
  end
end
