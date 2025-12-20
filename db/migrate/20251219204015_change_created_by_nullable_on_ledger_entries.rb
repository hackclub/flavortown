class ChangeCreatedByNullableOnLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ledger_entries, :created_by, true
  end
end
