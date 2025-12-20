class AddTutorialToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :tutorial, :boolean, default: false, null: false
  end
end
