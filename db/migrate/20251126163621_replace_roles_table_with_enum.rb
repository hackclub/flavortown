class ReplaceRolesTableWithEnum < ActiveRecord::Migration[8.1]
  def up
    add_column :user_role_assignments, :role, :integer

    # Load roles map directly here to ensure migration is self-contained-ish or at least consistent with intent
    # Hardcoded map based on config/roles.yml at the time of migration creation to avoid dependency on file existence
    roles_map = {
      "super_admin" => 0,
      "admin" => 1,
      "fraud_dept" => 2,
      "project_certifier" => 3,
      "ysws_reviewer" => 4,
      "fulfillment_person" => 5
    }

    # Migrate data
    # We iterate existing assignments, look up the old role name, find its index, and update.
    # Using raw SQL to avoid model validation/association issues during migration.

    connection.select_all("SELECT id, role_id FROM user_role_assignments").each do |assignment|
      role_id = assignment['role_id']
      # Get role name from roles table
      role_name_result = connection.select_value("SELECT name FROM roles WHERE id = #{role_id}")

      if role_name_result
        normalized_name = role_name_result.downcase.strip.gsub(' ', '_')
        # The YAML keys are CamelCase (e.g. Super_Admin), so underscore will make them super_admin.
        # The DB roles were created from keys, but the Role model normalized them: self.name = name.to_s.strip.downcase
        # So "Super_Admin" became "super_admin".

        new_role_int = roles_map[normalized_name]

        if new_role_int
          connection.execute("UPDATE user_role_assignments SET role = #{new_role_int} WHERE id = #{assignment['id']}")
        end
      end
    end

    # Make role non-null after population
    change_column_null :user_role_assignments, :role, false

    remove_column :user_role_assignments, :role_id
    drop_table :roles
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
