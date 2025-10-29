module ApplicationHelper
  def admin_tool(&block)
    if current_user&.admin?
      content_tag(:div, class: "admin tools-do", &block)
    end
  end

  def dev_tool(&block)
    if Rails.env.development?
      content_tag(:div, class: "dev tools-do", &block)
    end
  end
end
