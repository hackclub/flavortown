class DropUserRoleAssignments < ActiveRecord::Migration[8.1]
  def up
    drop_table :user_role_assignments
  end

  def down
    create_table :user_role_assignments do |t|
      t.bigint :user_id, null: false
      t.integer :role, null: false
      t.timestamps
      t.index :user_id
    end
    add_foreign_key :user_role_assignments, :users

    execute <<-SQL.squish
      INSERT INTO user_role_assignments (user_id, role, created_at, updated_at)
      SELECT
        users.id,
        CASE unnest(granted_roles)
          WHEN 'super_admin' THEN 0
          WHEN 'admin' THEN 1
          WHEN 'fraud_dept' THEN 2
          WHEN 'project_certifier' THEN 3
          WHEN 'ysws_reviewer' THEN 4
          WHEN 'fulfillment_person' THEN 5
        END,
        NOW(),
        NOW()
      FROM users
      WHERE array_length(granted_roles, 1) > 0
    SQL
  end
end
