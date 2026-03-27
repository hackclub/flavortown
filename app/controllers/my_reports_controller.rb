class MyReportsController < ApplicationController
  def index
    @reports = current_user.reports.includes(:project).order(created_at: :desc)
    @counts = {
      pending: current_user.reports.pending.count,
      reviewed: current_user.reports.reviewed.count,
      dismissed: current_user.reports.dismissed.count
    }
  end
end
