class AddRefToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :ref, :string
  end
end
