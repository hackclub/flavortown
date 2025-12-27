class RenameReportsToProjectReports < ActiveRecord::Migration[8.1]
  def change
    rename_table :reports, :project_reports
  end
end
