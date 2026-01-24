class AddAiDeclarationToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :ai_declaration, :text
  end
end
