class ProjectSearchService
  VEC_WEIGHT = 2.0
  FTS_WEIGHT = 1.0
  RRF_K = 60.0
  DEFAULT_POOL = 40
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100
  DESC_LEN_THRESHOLD = 100

  def initialize(query, limit: DEFAULT_LIMIT, rerank: false)
    @query = query.to_s.strip
    @limit = limit.to_i.clamp(1, MAX_LIMIT)
    @pool = [ DEFAULT_POOL, @limit * 2 ].max
    @rerank = rerank
  end

  def call
    return SearchResult.new(Project.none, @query, 0) if @query.blank?

    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    vec_ranked = vector_search
    fts_ranked = fulltext_search
    fused_ids = rrf_fusion(vec_ranked, fts_ranked)

    return SearchResult.new(Project.none, @query, 0) if fused_ids.empty?

    fused_ids = rerank_ids(fused_ids) if @rerank

    # Preserve ordering via SQL CASE
    order_clause = fused_ids.each_with_index.map { |id, i| "WHEN #{id} THEN #{i}" }.join(" ")
    projects = Project.where(id: fused_ids)
                      .includes(:devlogs)
                      .order(Arel.sql("CASE projects.id #{order_clause} END"))

    ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    SearchResult.new(projects, @query, ms)
  end

  private

  # Use a subquery for visible IDs to avoid DISTINCT + ORDER BY conflicts
  def visible_ids_subquery
    Project.where(deleted_at: nil).excluding_shadow_banned.select(:id)
  end

  def vector_search
    embedding = embed_model.(@query)
    Project.where(id: visible_ids_subquery)
           .where.not(embedding: nil)
           .nearest_neighbors(:embedding, embedding, distance: :cosine)
           .limit(@pool)
           .pluck(:id)
  rescue => e
    Rails.logger.warn("Vector search failed: #{e.message}")
    []
  end

  def fulltext_search
    Project.where(id: visible_ids_subquery)
           .text_search(@query)
           .limit(@pool)
           .pluck(:id)
  rescue => e
    Rails.logger.warn("FTS search failed: #{e.message}")
    []
  end

  def rrf_fusion(vec_ids, fts_ids)
    scores = Hash.new(0.0)

    vec_ids.each_with_index do |id, i|
      scores[id] += VEC_WEIGHT / (RRF_K + i + 1)
    end

    fts_ids.each_with_index do |id, i|
      scores[id] += FTS_WEIGHT / (RRF_K + i + 1)
    end

    scores.sort_by { |_, s| -s }.first(@pool).map(&:first)
  end

  def rerank_ids(candidate_ids)
    projects = Project.where(id: candidate_ids).pluck(:id, :description)
    docs = projects.map { |_, desc| desc.to_s[0, 256] }

    reranked = reranker.(@query, docs)

    # Discount short descriptions — they tend to be noisy
    reranked.each do |r|
      desc_len = docs[r[:doc_id]].length
      if desc_len < DESC_LEN_THRESHOLD
        r[:score] *= (desc_len.to_f / DESC_LEN_THRESHOLD)
      end
    end

    reranked.sort_by { |r| -r[:score] }
            .first(@limit)
            .map { |r| projects[r[:doc_id]].first }
  end

  def embed_model
    self.class.embed_model
  end

  def reranker
    self.class.reranker
  end

  class << self
    def embed_model
      @@embed_model ||= Informers.pipeline("embedding", "sentence-transformers/all-mpnet-base-v2")
    end

    def reranker
      @@reranker ||= Informers.pipeline("reranking", "cross-encoder/ms-marco-MiniLM-L-6-v2")
    end

    def warmup
      embed_model
      reranker
    end
  end

  SearchResult = Struct.new(:projects, :query, :ms)
end
