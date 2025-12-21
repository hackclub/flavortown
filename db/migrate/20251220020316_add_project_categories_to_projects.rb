class AddProjectCategoriesToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :project_categories, :string, array: true, default: []
  end
end
