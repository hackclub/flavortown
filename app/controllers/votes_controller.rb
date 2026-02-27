class VotesController < ApplicationController
  def index
    authorize :vote
    @pagy, @votes = pagy(current_user.votes.includes(:project, :ship_event).order(created_at: :desc))
  end

  def new
    authorize :vote
    @fullstory_org_id = Rails.application.credentials.dig(:fullstory, :org_id).presence
    @ship_event = VoteMatchmaker.new(current_user, user_agent: request.user_agent).next_ship_event
    return redirect_to root_path, notice: "No more projects to vote on!" unless @ship_event

    @suggestion_token = VoteSuggestionToken.issue(
      user: current_user,
      ship_event: @ship_event,
      user_agent: request.user_agent
    )

    @vote = Vote.new(ship_event: @ship_event, project: @ship_event.post.project)
    @project = @ship_event.post.project
    @posts = @project.posts.where("created_at <= ?", @ship_event.post.created_at)
                     .where.not(postable_type: "Post::GitCommit")
                     .order(created_at: :desc)
  end

  def create
    authorize :vote

    ship_event_id = VoteSuggestionToken.verify(
      params[:suggestion_token],
      user: current_user,
      user_agent: request.user_agent
    )

    unless ship_event_id
      return redirect_to(new_vote_path, alert: "Invalid or expired vote session. Please try again.")
    end

    ship_event = VoteableShipEventsQuery.call(user: current_user, user_agent: request.user_agent)
      .includes(post: :project)
      .find_by(id: ship_event_id)

    unless ship_event&.post&.project
      return redirect_to(new_vote_path, alert: "That project is no longer available for voting. Please try again.")
    end

    @vote = current_user.votes.build(vote_params)
    @vote.ship_event = ship_event
    @vote.project = ship_event.post.project

    if @vote.save
      share_vote_to_slack(@vote) if current_user.send_votes_to_slack
      redirect_to new_vote_path, notice: "Vote recorded! Thanks for your feedback."
    else
      redirect_to new_vote_path, alert: @vote.errors.full_messages.to_sentence
    end
  end

  private

  def vote_params
    params.require(:vote).permit(
      :reason,
      :demo_url_clicked,
      :repo_url_clicked,
      :time_taken_to_vote,
      *Vote.score_columns
    )
  end

  def share_vote_to_slack(vote)
    SendSlackDmJob.perform_later(
      "C0A2DTFSYSD",
      nil,
      blocks_path: "notifications/votes/shared",
      locals: {
        project: vote.project,
        reason: vote.reason,
        voter_slack_id: current_user.slack_id
      }
    )
  end
end
