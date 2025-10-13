class CreateUserRoleAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true

      t.timestamps
    end
    add_index :user_role_assignments, [ :user_id, :role_id ], unique: true
  end
end
