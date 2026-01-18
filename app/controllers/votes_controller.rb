class VotesController < ApplicationController
  before_action :check_voting_enabled

  def index
    authorize :vote
    @pagy, @votes = pagy(current_user.votes.includes(:project, :ship_event).order(created_at: :desc))
  end

  def new
    authorize :vote
    @ship_event = VoteMatchmaker.new(current_user, user_agent: request.user_agent).next_ship_event
    return redirect_to root_path, notice: "No more projects to vote on!" unless @ship_event

    @vote = Vote.new(ship_event: @ship_event, project: @ship_event.post.project)
    @project = @ship_event.post.project
    @posts = @project.posts.where("created_at <= ?", @ship_event.post.created_at)
                     .where.not(postable_type: "Post::GitCommit")
                     .order(created_at: :desc)
  end

  def create
    authorize :vote
    @vote = current_user.votes.build(vote_params)

    if @vote.save
      share_vote_to_slack(@vote) if current_user.send_votes_to_slack
      redirect_to new_vote_path, notice: "Vote recorded!"
    else
      @ship_event = @vote.ship_event
      @project = @vote.project
      @posts = @project.posts.where("created_at <= ?", @ship_event.post.created_at)
                     .where.not(postable_type: "Post::GitCommit")
                     .order(created_at: :desc)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def check_voting_enabled
    return if current_user && Flipper.enabled?(:voting, current_user)

    redirect_to root_path, alert: "Voting is currently disabled."
  end

  def vote_params
    params.require(:vote).permit(:ship_event_id, :project_id, :reason,
      :demo_url_clicked, :repo_url_clicked, :time_taken_to_vote, *Vote.score_columns)
  end

  def share_vote_to_slack(vote)
    SendSlackDmJob.perform_later(
      "C0A2DTFSYSD",
      nil,
      blocks_path: "notifications/votes/shared",
      locals: {
        project: vote.project,
        reason: vote.reason,
        anonymous: current_user.vote_anonymously,
        voter_slack_id: current_user.slack_id
      }
    )
  end
end
