class VectorizeProjectJob < ApplicationJob
  queue_as :vectorize

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project
    return if project.searchable_text.strip.length < 10

    embedding = embed_model.(project.searchable_text)
    project.update_column(:embedding, embedding)
  end

  private

  def embed_model
    ProjectSearchService.embed_model
  end
end
