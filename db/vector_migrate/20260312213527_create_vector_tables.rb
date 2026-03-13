require "sqlite_vec"

class CreateVectorTables < ActiveRecord::Migration[8.1]
  def up
    create_table :project_embeddings do |t|
      t.integer :project_id, null: false
      t.index :project_id, unique: true
    end

    # Load sqlite-vec so the vec0 module is available
    raw = ActiveRecord::Base.connection.raw_connection
    raw.enable_load_extension(true)
    SqliteVec.load(raw)
    raw.enable_load_extension(false)

    safety_assured do
      execute <<~SQL
        CREATE VIRTUAL TABLE project_embedding_vectors USING vec0(
          embedding float[768]
        )
      SQL
    end
  end

  def down
    drop_table :project_embeddings
    safety_assured { execute "DROP TABLE IF EXISTS project_embedding_vectors" }
  end
end
