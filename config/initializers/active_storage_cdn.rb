# Ensure Active Storage-generated URLs use the CDN host when available.
Rails.application.config.after_initialize do
  asset_host = Rails.application.config.asset_host
  next if asset_host.blank?

  begin
    uri = URI.parse(asset_host)
    host = uri.host.presence || asset_host
    protocol = uri.scheme.presence || "https"

    ActiveStorage::Current.url_options = {
      host: host,
      protocol: protocol
    }
  rescue URI::InvalidURIError
    ActiveStorage::Current.url_options = { host: asset_host, protocol: "https" }
  end
end


