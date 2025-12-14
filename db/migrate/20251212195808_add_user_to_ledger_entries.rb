class AddUserToLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :ledger_entries, :user_id, :bigint, null: true

    reversible do |dir|
      dir.up do
        puts "Denormalizing user data onto ledger_entries..."

        # For User ledger entries, set user_id = ledgerable_id
        execute <<-SQL
          UPDATE ledger_entries
          SET user_id = ledgerable_id
          WHERE ledgerable_type = 'User'
        SQL

        # For other ledgerable types, backfill to user_id = 1
        execute <<-SQL
          UPDATE ledger_entries
          SET user_id = 1
          WHERE ledgerable_type != 'User'
        SQL
      end
    end

    change_column_null :ledger_entries, :user_id, false
    add_foreign_key :ledger_entries, :users
    add_index :ledger_entries, :user_id
  end
end
