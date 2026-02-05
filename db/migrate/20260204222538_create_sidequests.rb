class CreateSidequests < ActiveRecord::Migration[8.1]
  def change
    create_table :sidequests do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :description
      t.string :external_page_link
      t.datetime :expires_at

      t.timestamps
    end

    add_index :sidequests, :slug, unique: true
  end
end
