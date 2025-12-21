class ExploreController < ApplicationController
  VARIANTS = %i[devlog fire certified ship].freeze

  def index
    non_tutorial_devlog_ids = Post::Devlog.where(tutorial: false).select(:id)
    scope = Post.includes(:user, :project, postable: { attachments_attachments: :blob })
                .where(postable_type: "Post::Devlog")
                .where("posts.postable_id::bigint IN (?)", non_tutorial_devlog_ids)
                .where.not(user_id: current_user&.id)
                .order(created_at: :desc)

    @pagy, @devlogs = pagy(scope)

    Rails.logger.debug "Devlogs count: #{@devlogs.size}, IDs: #{@devlogs.map(&:id)}"

    respond_to do |format|
      format.html
      format.json do
        html = @devlogs.map do |post|
          render_to_string(
            PostComponent.new(post: post, variant: devlog_variant(post), current_user: current_user),
            layout: false,
            formats: [ :html ]
          )
        end.join

        render json: {
          html: html,
          next_page: @pagy.next
        }
      end
    end
  end

  def gallery
    scope = Project.includes(banner_attachment: :blob)
                    .where(tutorial: false)
                    .where.not(id: current_user&.projects&.pluck(:id) || [])
                    .order(created_at: :desc)

    @pagy, @projects = pagy(scope)

    respond_to do |format|
      format.html
      format.json do
        html = @projects.map do |project|
          render_to_string(
            partial: "explore/card",
            locals: { project: project },
            layout: false,
            formats: [ :html ]
          )
        end.join

        render json: {
          html: html,
          next_page: @pagy.next
        }
      end
    end
  end

  def following
    unless current_user
      redirect_to login_path, alert: "You need to sign in to view followed projects." and return
    end

    scope = current_user.followed_projects
                        .where(tutorial: false)
                        .includes(:banner_attachment, posts: :postable)
                        .order(created_at: :desc)

    @pagy, @projects = pagy(scope)

    respond_to do |format|
      format.html
      format.json do
        html = @projects.map do |project|
          render_to_string(
            partial: "explore/card",
            locals: { project: project },
            layout: false,
            formats: [ :html ]
          )
        end.join

        render json: {
          html: html,
          next_page: @pagy.next
        }
      end
    end
  end

  private

  def devlog_variant(post)
    VARIANTS[post.id % VARIANTS.length]
  end
  helper_method :devlog_variant
end
