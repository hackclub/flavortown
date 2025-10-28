class CreateProjectIdeas < ActiveRecord::Migration[8.0]
  def change
    create_table :project_ideas do |t|
      t.text :content, null: false
      t.text :prompt, null: false
      t.string :model, null: false

      t.timestamps
    end
  end
end
