module ApplicationHelper
  def admin_tool &block
    if current_user&.admin?
      capture(&block)
    end
  end
  
  def dev_tool &block
    if Rails.env.development?
      capture(&block)
    end
  end
end
