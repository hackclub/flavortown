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

    recent = Vote.legitimate.includes(:project, ship_event: :post).order(created_at: :desc).limit(limit)
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

    @total_votes = total
    @recent_votes = recent_votes

    render :stats
  end

  # Final aggregated results for a project.
  def results
    if params[:project_id].present?
      project = Project.find_by(id: params[:project_id])
      return render(json: { error: "Project not found" }, status: :not_found) unless project

      # Prefer the most recent ship event using the current voting scale, fall back to latest ship event.
      ship_event = Post::ShipEvent.joins(:post)
        .where(posts: { project_id: project.id }, voting_scale_version: Post::ShipEvent::CURRENT_VOTING_SCALE_VERSION)
        .order("post_ship_events.created_at DESC").first

      ship_event ||= project.posts.of_ship_events.order("posts.created_at DESC").first&.ship_event
      return render(json: { error: "No ship event found for project" }, status: :not_found) unless ship_event

      mj = ship_event.majority_judgment

      render json: {
        ship_event_id: ship_event.id,
        project_id: project.id,
        project_title: project.title,
        votes_count: ship_event.votes.legitimate.count,
        majority_judgment: mj
      }
    else
      render json: { error: "project_id required" }, status: :bad_request
    end
  end

  # Return every vote record for a given project.
  def records
    unless params[:project_id].present?
      return render json: { error: "project_id required" }, status: :bad_request
    end

    scope = Vote.legitimate.includes(:user).order(created_at: :desc)

    if params[:project_id].present?
      # Return votes for the project
      scope = scope.where(project_id: params[:project_id])
    end

    limit = (params[:limit] || 100).to_i.clamp(1, 1000)
    votes = scope.limit(limit)

    result = votes.map do |v|
      user_info = if v.user&.vote_anonymously?
        nil
      else
        { id: v.user&.id, display_name: v.user&.display_name }
      end

      {
        id: v.id,
        user: user_info,
        project_id: v.project_id,
        ship_event_id: v.ship_event_id,
        originality_score: v.originality_score,
        technical_score: v.technical_score,
        usability_score: v.usability_score,
        storytelling_score: v.storytelling_score,
        reason: v.reason,
        time_taken_to_vote: v.time_taken_to_vote,
        suspicious: v.suspicious,
        created_at: v.created_at.iso8601
      }
    end

    render json: { votes: result }
  end

  # Latest global votes across all projects. Defaults to 100.
  def global
    limit = (params[:limit] || 100).to_i.clamp(1, 1000)

    scope = Vote.legitimate.includes(:user, :project).order(created_at: :desc)

    if params[:project_ids].present?
      raw_ids = params[:project_ids].to_s.split(",")
      normalized_ids = raw_ids.map { |id| id.strip }.reject(&:blank?)

      unless normalized_ids.present? && normalized_ids.all? { |id| id.match?(/\A\d+\z/) }
        return render json: { error: "Invalid project_ids format, expected comma-separated list of integers" }, status: :bad_request
      end
      ids = normalized_ids.map(&:to_i)
      scope = scope.where(project_id: ids)
    end

    votes = scope.limit(limit)

    result = votes.map do |v|
      user_info = if v.user&.vote_anonymously?
        nil
      else
        { id: v.user&.id, display_name: v.user&.display_name }
      end

      {
        id: v.id,
        project_id: v.project_id,
        project_title: v.project&.title,
        user: user_info,
        originality_score: v.originality_score,
        technical_score: v.technical_score,
        usability_score: v.usability_score,
        storytelling_score: v.storytelling_score,
        reason: v.reason,
        time_taken_to_vote: v.time_taken_to_vote,
        created_at: v.created_at.iso8601
      }
    end

    render json: { votes: result }
  end

  private
end
