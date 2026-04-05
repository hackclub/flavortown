# frozen_string_literal: true

class ProjectReadmeFetcher
  Result = Data.define(:markdown, :error)

  ALLOWED_HOSTS = %w[
    raw.githubusercontent.com
    github.com
    gitlab.com
    git.gay
    codeberg.org
    tangled.org
  ].freeze

  TIMEOUT_SECONDS = 10
  GITHUB_BLOB = %r{\Ahttps?://github\.com/([^/]+)/([^/]+)/blob/(.+)\z}

  def self.fetch(url)
    return Result.new(markdown: nil, error: "No README URL provided.") if url.blank?

    url = normalize_url(url)
    uri = URI.parse(url)
    return Result.new(markdown: nil, error: "Invalid README URL.") unless allowed_uri?(uri)

    conn = Faraday.new(headers: default_headers) do |faraday|
      faraday.response :follow_redirects, limit: 2
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get(uri.to_s) do |req|
      req.options.timeout = TIMEOUT_SECONDS
      req.options.open_timeout = TIMEOUT_SECONDS
    end

    return Result.new(markdown: nil, error: "README URL returned #{response.status}.") unless response.success?

    body = response.body.to_s

    if html_response?(response, body)
      return Result.new(markdown: nil, error: "README URL returned HTML instead of plain text. Use a raw content URL.")
    end

    Result.new(markdown: body, error: nil)
  rescue URI::InvalidURIError
    Result.new(markdown: nil, error: "Invalid README URL.")
  rescue Faraday::Error
    Result.new(markdown: nil, error: "Could not fetch README right now.")
  end

  def self.allowed_url?(url)
    return false if url.blank?

    uri = URI.parse(normalize_url(url.to_s))
    allowed_uri?(uri)
  rescue URI::InvalidURIError
    false
  end

  def self.allowed_uri?(uri)
    return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    host = uri.host.to_s.downcase
    return false if host.blank?
    ALLOWED_HOSTS.include?(host)
  end

  def self.normalize_url(url)
    return url unless (m = url.match(GITHUB_BLOB))

    "https://raw.githubusercontent.com/#{m[1]}/#{m[2]}/#{m[3]}"
  end

  def self.html_response?(res, body)
    res.headers["content-type"].to_s.downcase.include?("text/html") ||
      body.lstrip.start_with?("<!DOCTYPE", "<html")
  end

  def self.default_headers
    {
      "User-Agent" => "Flavortown README fetcher (https://flavortown.hackclub.com/)",
      "Accept" => "text/plain, text/markdown, */*"
    }
  end
end
