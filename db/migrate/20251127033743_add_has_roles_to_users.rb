class AddHasRolesToUsers < ActiveRecord::Migration[8.1]
  # you probably want to run OneTime::ResetUserHasRolesJob.perform_now after this
  def change
    add_column :users, :has_roles, :boolean, null: false,
                                             default: true,
                                             if_not_exists: true
  end
end
