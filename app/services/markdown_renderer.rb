class MarkdownRenderer
    def self.render(text)
        html = get_markdown(text)
        ActionController::Base.helpers.sanitize(html)
    end

    private

    def self.get_markdown(text)
        Commonmarker.to_html(
            text,
            options: {
                parse: { smart: true }
            }
        )
    end
end
