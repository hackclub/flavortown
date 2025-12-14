class AddGrantedRolesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :granted_roles, :string, array: true, default: [], null: false
  end
end
