class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :display_name
      t.integer :projects_count
      t.integer :votes_count

      t.timestamps
    end
  end
end
