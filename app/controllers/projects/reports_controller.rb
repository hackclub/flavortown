class Projects::ReportsController < ApplicationController
  def create
    authorize :report, :create?
    @project = ::Project.find(params[:project_id])

    if current_user.reports.exists?(project: @project)
      redirect_back_or_to project_path(@project), alert: "You have already reported this project."
      return
    end

    @report = current_user.reports.build(report_params.merge(project: @project))

    if @report.save
      redirect_back_or_to project_path(@project), notice: "Report submitted. Thank you for helping us maintain quality."
    else
      redirect_back_or_to project_path(@project), alert: @report.errors.full_messages.to_sentence
    end
  end

  private

    def report_params
      params.require(:project_report).permit(:reason, :details)
    end
end
