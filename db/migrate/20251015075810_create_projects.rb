class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :title, null: false
      t.text :description
      t.text :repo_url
      t.text :demo_url
      t.text :readme_url

      t.timestamps
    end
  end
end
