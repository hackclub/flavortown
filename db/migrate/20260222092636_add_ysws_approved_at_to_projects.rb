class AddYswsApprovedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :ysws_approved_at, :datetime
  end
end
