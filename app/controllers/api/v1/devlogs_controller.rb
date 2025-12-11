class Api::V1::DevlogsController < ApplicationController
  include ApiAuthenticatable

  def index
    @pagy, @devlogs = pagy(
      Post::Devlog
        .joins("INNER JOIN posts ON posts.postable_id::bigint = post_devlogs.id AND posts.postable_type = 'Post::Devlog'")
        .where(posts: { project_id: params[:project_id] })
        .order("post_devlogs.created_at DESC"),
      items: 100
    )
  end

  def show
    @devlog = Post::Devlog
      .joins("INNER JOIN posts ON posts.postable_id::bigint = post_devlogs.id AND posts.postable_type = 'Post::Devlog'")
      .where(posts: { project_id: params[:project_id] })
      .find_by!(id: params[:id])

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end
end
