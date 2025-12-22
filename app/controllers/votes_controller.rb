class VotesController < ApplicationController
  before_action :ensure_user_can_vote, only: [ :index, :new, :create ]

  def index
    authorize :vote, :index?
    # Get distinct project IDs ordered by the user's most recent vote for that project
    project_ids = Vote.where(user: current_user)
                      .select("project_id, MAX(created_at) as max_created_at")
                      .group(:project_id)
                      .order("max_created_at DESC")
                      .map(&:project_id)

    # Paginate the array of project IDs
    @pagy, @project_ids = pagy(:offset, project_ids)

    # Fetch the votes for the paginated project IDs
    @votes_by_project = Vote.where(user: current_user, project_id: @project_ids)
                            .includes(:project)
                            .group_by(&:project)
                            # Sort by the order of project_ids (most recent first)
                            .sort_by { |project, _| @project_ids.index(project.id) }
  end

  def new
    authorize :vote, :new?
    project_id = Project.looking_for_votes
                        .votable_by(current_user)
                        .limit(10)
                        .pluck(:id)
                        .sample

    @project = Project.find_by(id: project_id)
    @devlogs = if @project
                 @project.posts.includes(:postable, :user).order(created_at: :desc).limit(5)
    else
                 []
    end
  end

  def create
    authorize :vote, :create?
    @project = Project.find(params[:project_id])

    created_votes = []

    Vote.transaction do
      votes_params = params.require(:votes)

      Rails.logger.info "VOTE PARAMS: time=#{params[:time_taken_to_vote]}, repo=#{params[:repo_url_clicked]}, demo=#{params[:demo_url_clicked]}"

      votes_params.values.each do |vote_params|
        created_votes << current_user.votes.create!(
          project: @project,
          category: vote_params[:category],
          score: vote_params[:score],
          time_taken_to_vote: params[:time_taken_to_vote].to_i,
          repo_url_clicked: params[:repo_url_clicked] == "true",
          demo_url_clicked: params[:demo_url_clicked] == "true",
          reason: params[:reason].presence
        )
      end
    end

    share_vote_to_slack(created_votes, params[:reason].presence) if current_user.send_votes_to_slack

    redirect_to new_vote_path, notice: "Voted!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_vote_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def share_vote_to_slack(votes, reason)
    return if votes.empty?

    SendSlackDmJob.perform_later(
      "C0A2DTFSYSD",
      nil,
      blocks_path: "notifications/votes/shared",
      locals: {
        project: votes.first.project,
        reason: reason,
        anonymous: false,
        voter_slack_id: current_user.slack_id
      }
    )
  end

  def ensure_user_can_vote
    unless current_user
      redirect_to login_path, alert: "You need to log in to vote."
      return
    end

    return if current_user.admin? || current_user.verification_verified?

    tutorial_message "Hold on — voting unlocks after your account is verified!"
    redirect_to kitchen_path
  end
end
