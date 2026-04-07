class AddResolutionReasonToProjectReports < ActiveRecord::Migration[8.1]
  def change
    add_column :project_reports, :resolution_reason, :text
  end
end
