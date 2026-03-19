class Api::V1::VotesController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    stats: "Fetch aggregated voting statistics..."
  }

  class_attribute :url_params_model, default: {
    stats: {
      limit: { type: Integer, desc: "Number of recent votes to return (default 20)", required: false }
    }
  }

  class_attribute :response_body_model, default: {
    stats: { total_votes: Integer, recent_votes: [ { project_id: Integer, project_title: String, vote_timestamp: String, time_spent: Integer, ship_date: "String || Null", days_ago: "Integer || Null" } ] }
  }

  def stats
    limit = (params[:limit] || 20).to_i.clamp(1, 100)

    recent = Vote.legitimate.includes(:project, :ship_event).order(created_at: :desc).limit(limit)
    total = Vote.legitimate.count

    recent_votes = recent.map do |v|
      ship_date = v.ship_event&.post&.created_at
      days_ago = ship_date ? (Time.zone.now.to_date - ship_date.to_date).to_i : nil

      {
        project_id: v.project_id,
        project_title: v.project&.title,
        vote_timestamp: v.created_at.iso8601,
        time_spent: v.time_taken_to_vote,
        ship_date: ship_date&.iso8601,
        days_ago: days_ago
      }
    end

    render json: { total_votes: total, recent_votes: recent_votes }
  end

  private
end
