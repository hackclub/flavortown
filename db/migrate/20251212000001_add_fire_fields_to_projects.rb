class AddFireFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :marked_fire_at, :datetime
    add_reference :projects, :marked_fire_by, foreign_key: { to_table: :users }
  end
end
