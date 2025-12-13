class AddRolesToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :roles, :string, array: true, default: []

    execute <<-SQL
      UPDATE users
      SET roles = COALESCE(
        (
          SELECT array_agg(
            CASE role
              WHEN 0 THEN 'super_admin'
              WHEN 1 THEN 'admin'
              WHEN 2 THEN 'fraud_dept'
              WHEN 3 THEN 'project_certifier'
              WHEN 4 THEN 'ysws_reviewer'
              WHEN 5 THEN 'fulfillment_person'
            END
          )
          FROM user_role_assignments
          WHERE user_role_assignments.user_id = users.id
        ),
        '{}'
      )
    SQL

    remove_column :users, :has_roles
    drop_table :user_role_assignments
  end

  def down
    create_table :user_role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false
      t.timestamps
    end

    add_column :users, :has_roles, :boolean, null: false, default: true

    User.find_each do |user|
      user.roles.each do |role_name|
        role_int = case role_name
        when "super_admin" then 0
        when "admin" then 1
        when "fraud_dept" then 2
        when "project_certifier" then 3
        when "ysws_reviewer" then 4
        when "fulfillment_person" then 5
        end
        execute("INSERT INTO user_role_assignments (user_id, role, created_at, updated_at) VALUES (#{user.id}, #{role_int}, NOW(), NOW())")
      end
      user.update_column(:has_roles, user.roles.any?)
    end

    remove_column :users, :roles
  end
end
