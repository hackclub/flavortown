class ChangeLedgerEntryCreatedByToString < ActiveRecord::Migration[8.0]
  def up
    add_column :ledger_entries, :created_by_temp, :string

    execute <<-SQL
      UPDATE ledger_entries
      SET created_by_temp = (
        SELECT CONCAT(users.display_name, ' (', users.id, ')')
        FROM users
        WHERE users.id = ledger_entries.created_by_id
      )
    SQL

    execute <<-SQL
      UPDATE ledger_entries
      SET created_by_temp = CONCAT('Unknown (', created_by_id, ')')
      WHERE created_by_temp IS NULL
    SQL

    remove_foreign_key :ledger_entries, column: :created_by_id
    remove_index :ledger_entries, :created_by_id
    remove_column :ledger_entries, :created_by_id

    rename_column :ledger_entries, :created_by_temp, :created_by
    change_column_null :ledger_entries, :created_by, false
  end

  def down
    add_reference :ledger_entries, :created_by, foreign_key: { to_table: :users }, null: true

    execute <<-SQL
      UPDATE ledger_entries
      SET created_by_id = (
        REGEXP_REPLACE(created_by, '.*\\(([0-9]+)\\)$', '\\1')::bigint
      )
    SQL

    change_column_null :ledger_entries, :created_by_id, false
    remove_column :ledger_entries, :created_by
    rename_column :ledger_entries, :created_by_id, :created_by_id
  end
end
