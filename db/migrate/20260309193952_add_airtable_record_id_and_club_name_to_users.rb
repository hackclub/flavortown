class AddAirtableRecordIdAndClubNameToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :airtable_record_id, :string
    add_column :users, :club_name, :string
    add_column :users, :club_link, :string

    add_index :users, :airtable_record_id, unique: true, algorithm: :concurrently
  end
end
