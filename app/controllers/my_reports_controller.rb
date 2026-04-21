class MyReportsController < ApplicationController
  before_action :require_login
  def index
    @pagy, @reports = pagy(current_user.reports.includes(:project).order(created_at: :desc), limit: 25)
    @counts = {
      pending: current_user.reports.pending.count,
      reviewed: current_user.reports.reviewed.count,
      dismissed: current_user.reports.dismissed.count
    }
  end
end
