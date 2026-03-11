class AddVectorSearchToProjects < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      enable_extension "vector"

      add_column :projects, :embedding, :vector, limit: 768
      add_column :projects, :searchable_tsv, :tsvector

      add_index :projects, :searchable_tsv, using: :gin, algorithm: :concurrently

      # Auto-update tsvector when title or description changes
      execute <<-SQL
        CREATE TRIGGER projects_searchable_tsv_update
        BEFORE INSERT OR UPDATE OF title, description ON projects
        FOR EACH ROW EXECUTE FUNCTION
          tsvector_update_trigger(searchable_tsv, 'pg_catalog.english', title, description);
      SQL
    end
  end

  def down
    execute "DROP TRIGGER IF EXISTS projects_searchable_tsv_update ON projects"
    remove_column :projects, :searchable_tsv
    remove_column :projects, :embedding
    disable_extension "vector"
  end
end
