class MarkdownRenderer
  def self.render(content)
    return "" if content.blank?
    
    Commonmarker.to_html(
      content,
      options: {
        parse: { smart: true },
        render: { unsafe: false }
      }
    )
  end
end
