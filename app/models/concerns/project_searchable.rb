module ProjectSearchable
  extend ActiveSupport::Concern

  class_methods do
    def text_search(query)
      where("searchable_tsv @@ websearch_to_tsquery('english', ?)", query)
        .select("projects.*, ts_rank(searchable_tsv, websearch_to_tsquery('english', #{connection.quote(query)})) AS text_rank")
        .order(Arel.sql("ts_rank(searchable_tsv, websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
    end
  end

  def searchable_text
    "#{title} #{description}"
  end
end
