class EmbeddingsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :embeddings, reading: :embeddings }
end
