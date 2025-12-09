class MarkdownRenderer
    def self.render(text)
        html = get_markdown(text)
        sanitised = ActionController::Base.helpers.sanitize(html)
        doc = Nokogiri::HTML::DocumentFragment.parse(sanitised)
        doc.css("a").each do |link|
          link["target"] = "_blank"
          link["rel"] = "noopener noreferrer"
        end
        doc.to_html
    end

    private

    def self.get_markdown(text)
        html = Commonmarker.to_html(
            text,
            options: {
                parse: { smart: true }
            }
        )
    end
end
