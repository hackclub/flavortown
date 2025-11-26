class VotesController < ApplicationController
  before_action :authenticate_user!

  def index
    # Get distinct project IDs ordered by the user's most recent vote for that project
    project_ids = Vote.where(user: current_user)
                      .select("project_id, MAX(created_at) as max_created_at")
                      .group(:project_id)
                      .order("max_created_at DESC")
                      .map(&:project_id)

    # Paginate the array of project IDs
    @pagy, @project_ids = pagy(project_ids)

    # Fetch the votes for the paginated project IDs
    @votes_by_project = Vote.where(user: current_user, project_id: @project_ids)
                            .includes(:project)
                            .group_by(&:project)
                            # Sort by the order of project_ids (most recent first)
                            .sort_by { |project, _| @project_ids.index(project.id) }
  end

  def new
    # new vote
    @project = Project.votable_by(current_user).first
  end

  def create
    @project = Project.find(params[:project_id])

    Vote.transaction do
      votes_params = params.require(:votes)
      votes_params.each do |vote_params|
        current_user.votes.create!(
          project: @project,
          category: vote_params[:category],
          score: vote_params[:score]
        )
      end
    end

    redirect_to new_vote_path, notice: "Voted!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_vote_path, alert: e.record.errors.full_messages.to_sentence
  end
end
