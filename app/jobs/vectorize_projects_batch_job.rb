class VectorizeProjectsBatchJob < ApplicationJob
  queue_as :vectorize

  BATCH_SIZE = 100

  def perform
    backfill_tsvectors
    vectorize_embeddings
  end

  private

  def backfill_tsvectors
    # Backfill any rows where the trigger hasn't populated searchable_tsv yet
    updated = Project.where(searchable_tsv: nil).limit(BATCH_SIZE).update_all(
      "searchable_tsv = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))"
    )
    Rails.logger.info("[VectorizeProjectsBatchJob] Backfilled #{updated} tsvectors") if updated > 0
  end

  def vectorize_embeddings
    embedded_ids = ProjectEmbedding.embedded_project_ids
    projects = Project.where.not(description: [ nil, "" ])
                      .where.not(id: embedded_ids.to_a)
                      .limit(BATCH_SIZE)
    return if projects.empty?

    model = ProjectSearchService.embed_model
    count = 0

    projects.find_each do |project|
      next if project.searchable_text.strip.length < 10

      embedding = model.(project.searchable_text)
      ProjectEmbedding.upsert_embedding(project_id: project.id, embedding: embedding)
      count += 1
    end

    Rails.logger.info("[VectorizeProjectsBatchJob] Vectorized #{count} projects")

    # Re-enqueue if there's more work
    remaining = Project.where.not(description: [ nil, "" ]).where.not(id: ProjectEmbedding.embedded_project_ids.to_a)
    if remaining.exists? || Project.where(searchable_tsv: nil).exists?
      self.class.perform_later
    else
      Rails.logger.info("[VectorizeProjectsBatchJob] All projects vectorized!")
    end
  end
end
