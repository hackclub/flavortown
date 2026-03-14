module ProjectSearchable
  extend ActiveSupport::Concern

  included do
    has_neighbors :embedding
  end

  class_methods do
    def text_search(query)
      where("searchable_tsv @@ websearch_to_tsquery('english', ?)", query)
        .select("projects.*, ts_rank(searchable_tsv, websearch_to_tsquery('english', #{connection.quote(query)})) AS text_rank")
        .order(Arel.sql("ts_rank(searchable_tsv, websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
    end

    def needs_embedding
      where(embedding: nil).where.not(description: [ nil, "" ])
    end
  end

  def searchable_text
    "#{title} #{description}"
  end
end
