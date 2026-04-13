class Vote::ScoreReasonQualityJob < ApplicationJob
  queue_as :default

  OPENAI_EMBEDDINGS_URL = "https://api.openai.com/v1/embeddings"

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 5

  def perform(vote_id)
    vote = Vote.includes(:project).find_by(id: vote_id)
    return if vote.nil? || vote.reason_quality_label?

    result = Secrets::VoteReasonScorer.call(embedding_for(vote))

    vote.update_columns(reason_quality_label: result.label, reason_quality_score: result.score)
  end

  private

  def embedding_for(vote)
    Vote::ReasonEmbedding.find_by(vote_id: vote.id)&.embedding ||
      generate_and_cache_embedding(vote)
  end

  def generate_and_cache_embedding(vote)
    text = "reason: #{vote.reason.strip}\nproject: #{vote.project&.title} — #{vote.project&.description&.to_s&.strip&.slice(0, 200)}"
    vector = fetch_embedding(text)
    Vote::ReasonEmbedding.create!(vote_id: vote.id, embedding: vector, model_version: Vote::ReasonEmbedding::EMBED_MODEL)
    vector
  end

  def fetch_embedding(text)
    response = openai_connection.post { |r| r.body = { model: Vote::ReasonEmbedding::EMBED_MODEL, input: text } }
    raise "OpenAI embeddings error #{response.status}: #{response.body}" unless response.success?

    response.body.dig("data", 0, "embedding")
  end

  def openai_connection
    @openai_connection ||= Faraday.new(url: OPENAI_EMBEDDINGS_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.headers["Authorization"] = "Bearer #{openai_api_key}"
      f.options.timeout = 30
      f.options.open_timeout = 10
      f.adapter :net_http
    end
  end

  def openai_api_key
    Rails.application.credentials.dig(:openai, :api_key) || ENV.fetch("OPENAI_API_KEY")
  end
end
