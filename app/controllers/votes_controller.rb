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
    redirect_to root_path, alert: "Voting is currently disabled."
    nil
  end

  def create
    authorize :vote, :create?
    redirect_to root_path, alert: "Voting is currently disabled."
    nil
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
