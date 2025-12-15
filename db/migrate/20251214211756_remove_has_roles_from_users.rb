class RemoveHasRolesFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :has_roles, :boolean, default: true, null: false
  end
end
