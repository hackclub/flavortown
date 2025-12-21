# lib/middleware/serve_avif.rb
class ServeAvif
  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]
    accept = env["HTTP_ACCEPT"] || ""

    if path =~ %r{^/assets/.+\.(png|jpe?g)$} && accept.include?("image/avif")
      avif_path = File.join(Rails.public_path, "#{path}.avif")

      if File.exist?(avif_path)
        return [
          200,
          {
            "Content-Type" => "image/avif",
            "Cache-Control" => "public, max-age=31536000",
            "Vary" => "Accept"
          },
          [ File.binread(avif_path) ]
        ]
      end
    end

    # Fall through to Rails - but we need to add short cache + Vary header for PNGs
    status, headers, response = @app.call(env)

    if path =~ %r{^/assets/.+\.(png|jpe?g)$}
      headers["Vary"] = "Accept"
      # Short cache if browser wanted AVIF but we don't have it yet
      if accept.include?("image/avif")
        headers["Cache-Control"] = "public, max-age=60"
      end
    end

    [ status, headers, response ]
  end
end
