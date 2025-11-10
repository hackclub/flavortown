Rails.application.config.to_prepare do
  Blazer::QueriesController.class_eval do
    prepend_before_action :check_creator_permission

    private

    def check_creator_permission
      return unless %w[new create edit update destroy].include?(action_name)

      user = User.find_by(id: session[:user_id])
      unless user&.admin?
        flash[:alert] = "Only admins can create, edit, or delete queries."
        redirect_to "/admin/blazer"
      end
    end
  end
end
