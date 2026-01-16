class AddInternalNotesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :internal_notes, :text
  end
end
