# == Schema Information
#
# Table name: project_embeddings
# Database name: vector
#
#  id         :integer          not null, primary key
#  project_id :integer          not null
#
# Indexes
#
#  index_project_embeddings_on_project_id  (project_id) UNIQUE
#
class ProjectEmbedding < VectorRecord
  DIMENSIONS = 768

  after_destroy :remove_vector

  def self.upsert_embedding(project_id:, embedding:)
    result = upsert({ project_id: project_id }, unique_by: :project_id)
    record_id = find_by!(project_id: project_id).id

    blob = embedding.pack("f*")
    connection.raw_connection.execute(
      "INSERT OR REPLACE INTO project_embedding_vectors (rowid, embedding) VALUES (?, ?)", [record_id, blob]
    )
    result
  end

  def self.search(embedding, limit: 40)
    blob = embedding.pack("f*")
    rows = connection.raw_connection.execute(<<~SQL, [blob, limit])
      SELECT pe.project_id
      FROM project_embedding_vectors v
      INNER JOIN project_embeddings pe ON pe.id = v.rowid
      WHERE v.embedding MATCH ? AND k = ?
      ORDER BY v.distance
    SQL
    rows.map { |r| r["project_id"] }
  end

  def self.embedded_project_ids
    pluck(:project_id).to_set
  end

  private

  def remove_vector
    self.class.connection.raw_connection.execute(
      "DELETE FROM project_embedding_vectors WHERE rowid = ?", [id]
    )
  end
end
