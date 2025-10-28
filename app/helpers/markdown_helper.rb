module MarkdownHelper
    def md(text)
        MarkdownRenderer.render(text).html_safe
    end
end
