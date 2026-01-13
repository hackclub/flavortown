class MarkdownRenderer
  def self.render(text)
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

    doc.to_html
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
