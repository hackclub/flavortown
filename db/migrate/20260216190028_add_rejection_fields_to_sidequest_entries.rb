class AddRejectionFieldsToSidequestEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :sidequest_entries, :rejection_message, :text
    add_column :sidequest_entries, :is_rejection_fee_charged, :boolean, default: false, null: false
  end
end
