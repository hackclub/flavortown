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
    projects = Project.needs_embedding.limit(BATCH_SIZE)
    return if projects.empty?

    model = ProjectSearchService.embed_model
    count = 0

    projects.find_each do |project|
      next if project.searchable_text.strip.length < 10

      embedding = model.(project.searchable_text)
      project.update_column(:embedding, embedding)
      count += 1
    end

    Rails.logger.info("[VectorizeProjectsBatchJob] Vectorized #{count} projects")

    # Re-enqueue if there's more work
    if Project.needs_embedding.exists? || Project.where(searchable_tsv: nil).exists?
      self.class.perform_later
    else
      Rails.logger.info("[VectorizeProjectsBatchJob] All projects vectorized!")
    end
  end
end
