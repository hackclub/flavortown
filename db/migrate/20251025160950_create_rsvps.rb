class CreateRsvps < ActiveRecord::Migration[8.0]
  def change
    create_table :rsvps do |t|
      t.string :email, null: false

      t.timestamps
    end
  end
end
