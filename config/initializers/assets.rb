# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add secret assets if the secrets submodule is present
# Structure: secrets/assets/images/, secrets/assets/stylesheets/, etc.
secrets_assets = Rails.root.join("secrets", "assets")
if secrets_assets.exist?
  Rails.application.config.assets.paths << secrets_assets.join("images")
  Rails.application.config.assets.paths << secrets_assets.join("stylesheets")
end
