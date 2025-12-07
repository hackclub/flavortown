class AddShippingFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :project_type, :string
    add_column :projects, :ship_status, :string, default: "draft"
    add_column :projects, :shipped_at, :datetime
  end
end
