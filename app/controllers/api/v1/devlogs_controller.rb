class Api::V1::DevlogsController < ApplicationController
  include ApiAuthenticatable

  class_attribute :url_params, default: {}
  class_attribute :response, default: {}

  self.url_params = {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  self.response = {
    index: [
      {
        id: Integer,
        body: String,
        comments_count: Integer,
        duration_seconds: Integer,
        likes_count: Integer,
        scrapbook_url: String,
        created_at: String,
        updated_at: String
      }
    ],

    show: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String
    }
  }

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
