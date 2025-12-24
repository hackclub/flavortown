# lib/middleware/no_cache_errors.rb
class NoCacheErrors
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    if status == 404 && env["PATH_INFO"].start_with?("/assets/")
      headers["Cache-Control"] = "no-store"
    end

    [ status, headers, response ]
  end
end
