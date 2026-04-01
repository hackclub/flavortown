# frozen_string_literal: true

# Ferret requires FERRET=true to activate. Without it, the gem is loaded but
# no models are downloaded, no embeddings are computed, and search endpoints
# return 503. This keeps boot fast for developers who don't need search.

Ferret.configure do |config|
  # Path to the sidecar SQLite database (no changes to your primary DB)
  config.database_path = Rails.root.join("db/ferret/ferret.sqlite3")

  # Embedding model (runs locally via ONNX, no API keys needed)
  # config.embedding_model = "sentence-transformers/all-mpnet-base-v2"

  # Cross-encoder reranker model
  # config.reranker_model = "cross-encoder/ms-marco-MiniLM-L-6-v2"

  # ActiveJob queue for background embedding
  # config.queue = :default

  # Disable auto-embedding unless FERRET is enabled
  config.embed_on_save = ENV["FERRET"].present?

  # Enable cross-encoder reranking (slower but more accurate)
  # config.rerank = true
end
