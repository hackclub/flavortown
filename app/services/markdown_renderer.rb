class MarkdownRenderer
  CACHE = {}
  CACHE_MUTEX = Mutex.new
  MAX_CACHE_SIZE = 500

  def self.render(text)
    return "".freeze if text.blank?

    cache_key = text.hash
    cached = CACHE_MUTEX.synchronize { CACHE[cache_key] }
    return cached if cached

    html = get_markdown(text)

    sanitised = ActionController::Base.helpers.sanitize(
      html,
      tags: ActionView::Base.sanitized_allowed_tags + [ "u" ],
      attributes: ActionView::Base.sanitized_allowed_attributes + [ "target", "rel" ],
      protocols: {
        "a" => { "href" => [ "http", "https", "mailto" ] },
        "img" => { "src" => [ "http", "https" ] }
      }
    )

    doc = Nokogiri::HTML::DocumentFragment.parse(sanitised)

    doc.css("a").each do |link|
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    end

    doc.css("img").each do |img|
      img["loading"] = "lazy"
      img["decoding"] = "async"
      img["referrerpolicy"] = "no-referrer"
    end

    result = doc.to_html.freeze

    CACHE_MUTEX.synchronize do
      CACHE.shift if CACHE.size >= MAX_CACHE_SIZE
      CACHE[cache_key] = result
    end

    result
  end

  private

  def self.get_markdown(text)
    Commonmarker.to_html(
      text,
      options: {
        parse: { smart: true },
        extension: {
          strikethrough: true,
          underline: true,
          table: true
        }
      }
    )
  end
end
