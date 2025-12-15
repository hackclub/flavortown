module ProjectsHelper
  def safe(url, text = nil)
    return unless url.present? && url.start_with?("http")
    link_to(text || url, url, target: "_blank")
  end
end
