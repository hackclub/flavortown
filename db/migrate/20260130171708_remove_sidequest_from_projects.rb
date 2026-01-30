class RemoveSidequestFromProjects < ActiveRecord::Migration[8.1]
  def change
    remove_column :projects, :sidequest, :string
  end
end
