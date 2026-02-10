# lib/middleware/no_cache_errors.rb
class NoCacheErrors
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/assets/")

    status, headers, response = @app.call(env)

    headers["Cache-Control"] = "no-store" if status == 404

    [ status, headers, response ]
  end
end
