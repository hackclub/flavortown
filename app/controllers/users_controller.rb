class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    authorize @user

    @projects = @user.projects
                     .select(:id, :title, :created_at, :ship_status, :shipped_at, :devlogs_count)
                     .order(created_at: :desc)
                     .includes(banner_attachment: :blob)

    @activity = Post.includes(:project, :user, postable: [ { attachments_attachments: :blob } ])
                          .where(user_id: @user.id)
                          .order(created_at: :desc)

    post_counts_by_type = Post.where(user_id: @user.id).group(:postable_type).count
    posts_count = post_counts_by_type.values.sum
    ships_count = post_counts_by_type["Post::ShipEvent"] || 0

    votes_count = @user.votes_count || Vote.where(user_id: @user.id).count

    @stats = {
      posts_count: posts_count,
      projects_count: @user.projects_count || @user.projects.size,
      ships_count: ships_count,
      votes_count: votes_count,
      hours_today: (@user.devlog_seconds_today / 3600.0).round(1),
      hours_all_time: (@user.devlog_seconds_total / 3600.0).round(1)
    }
  end
end
