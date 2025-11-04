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
  def random_carousel_transform
    "rotate(#{rand(-3..3)}deg) scale(#{(rand(97..103).to_f / 100).round(2)}) translateY(#{rand(-8..8)}px)"
  end
end
