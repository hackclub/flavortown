class MoveRoleAssignmentsToRoles < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL.squish
      UPDATE users
      SET granted_roles = subquery.role_names
      FROM (
        SELECT user_id, ARRAY_AGG(
          CASE role
            WHEN 0 THEN 'super_admin'
            WHEN 1 THEN 'admin'
            WHEN 2 THEN 'fraud_dept'
            WHEN 3 THEN 'project_certifier'
            WHEN 4 THEN 'ysws_reviewer'
            WHEN 5 THEN 'fulfillment_person'
          END
        ) AS role_names
        FROM user_role_assignments
        GROUP BY user_id
      ) AS subquery
      WHERE users.id = subquery.user_id
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE users
      SET granted_roles = '{}'
    SQL
  end
end
