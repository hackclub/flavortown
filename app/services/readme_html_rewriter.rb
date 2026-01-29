# frozen_string_literal: true

require "nokogiri"
require "uri"

class ReadmeHtmlRewriter
  def self.rewrite(html:, readme_url:)
    return html if html.blank? || readme_url.blank?

    base = base_uri_for(readme_url)
    return html unless base

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("img[src]").each do |img|
      img["src"] = rewrite_url(img["src"], base: base)
    end

    fragment.css("a[href]").each do |a|
      a["href"] = rewrite_url(a["href"], base: base)
    end

    fragment.to_html
  rescue URI::InvalidURIError
    html
  end

  def self.rewrite_url(value, base:)
    return value if value.blank?
    return value if value.start_with?("#", "mailto:", "tel:", "data:")

    absolute = absolutize(value, base: base)
    github_blob_to_raw(absolute)
  end
  private_class_method :rewrite_url

  def self.absolutize(value, base:)
    uri = URI.parse(value)
    return value if uri.host.present? # already absolute

    URI.join(base.to_s, value).to_s
  rescue URI::InvalidURIError
    value
  end
  private_class_method :absolutize

  def self.github_blob_to_raw(url)
    uri = URI.parse(url)
    return url unless uri.host&.downcase == "github.com"

    parts = uri.path.to_s.split("/").reject(&:blank?)

    return url unless parts.length >= 5 && parts[2] == "blob"

    owner = parts[0]
    repo  = parts[1]
    ref   = parts[3]
    path  = parts[4..].join("/")

    "https://raw.githubusercontent.com/#{owner}/#{repo}/#{ref}/#{path}"
  rescue URI::InvalidURIError
    url
  end
  private_class_method :github_blob_to_raw

  def self.base_uri_for(readme_url)
    uri = URI.parse(readme_url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    dir = uri.path.to_s.sub(%r{[^/]+\z}, "")
    uri.path = dir
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  end
  private_class_method :base_uri_for
end
