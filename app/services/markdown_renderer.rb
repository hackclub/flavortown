class MarkdownRenderer
    def self.render(text)
        html = get_markdown(text)

        sanitised = ActionController::Base.helpers.sanitize(
            html,
            tags: ActionView::Base.sanitized_allowed_tags + ["u"]
        )

        doc = Nokogiri::HTML::DocumentFragment.parse(sanitised)

        doc.css("a").each do |link|
          link["target"] = "_blank"
          link["rel"] = "noopener noreferrer"
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
                    table: true,
                },
                render: { unsafe: true } # this should be fine as we sanitize later
            }
        )
    end
end
