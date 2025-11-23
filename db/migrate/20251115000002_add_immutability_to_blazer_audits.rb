class AddImmutabilityToBlazerAudits < ActiveRecord::Migration[8.0]
  def up
    # Remove updated_at column if it exists (audits should never be updated)
    remove_column :blazer_audits, :updated_at if column_exists?(:blazer_audits, :updated_at)

    # Add index on created_at for better query performance
    add_index :blazer_audits, :created_at unless index_exists?(:blazer_audits, :created_at)

    # Create trigger function to prevent updates and deletes
    execute <<-SQL
      CREATE OR REPLACE FUNCTION prevent_blazer_audit_changes()
      RETURNS TRIGGER AS $$
      BEGIN
        RAISE EXCEPTION 'Blazer audit logs are immutable and cannot be modified or deleted';
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Create triggers for UPDATE and DELETE
    execute <<-SQL
      CREATE TRIGGER prevent_blazer_audit_updates
      BEFORE UPDATE ON blazer_audits
      FOR EACH ROW
      EXECUTE FUNCTION prevent_blazer_audit_changes();
    SQL

    execute <<-SQL
      CREATE TRIGGER prevent_blazer_audit_deletes
      BEFORE DELETE ON blazer_audits
      FOR EACH ROW
      EXECUTE FUNCTION prevent_blazer_audit_changes();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS prevent_blazer_audit_deletes ON blazer_audits;"
    execute "DROP TRIGGER IF EXISTS prevent_blazer_audit_updates ON blazer_audits;"
    execute "DROP FUNCTION IF EXISTS prevent_blazer_audit_changes();"

    add_index :blazer_audits, :created_at if index_exists?(:blazer_audits, :created_at)
  end
end
