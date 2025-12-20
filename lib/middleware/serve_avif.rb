class ServeAvif
  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]
    accept = env["HTTP_ACCEPT"] || ""

    # Only intercept asset image requests
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

    @app.call(env)
  end
end
