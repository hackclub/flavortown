class AddSidequestToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :sidequest, :string
  end
end
