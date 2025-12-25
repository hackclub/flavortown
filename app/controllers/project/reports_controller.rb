class Project::ReportsController < ApplicationController
  def create
    authorize :report, :create?
    @project = ::Project.find(params[:project_id])

    @report = current_user.reports.build(report_params.merge(project: @project))

    if @report.save
      redirect_to new_vote_path, notice: "Report submitted. Thank you for helping us maintain quality."
    else
      redirect_to new_vote_path, alert: @report.errors.full_messages.to_sentence
    end
  end

  private

    def report_params
      params.require(:project_report).permit(:reason, :details)
    end
end
