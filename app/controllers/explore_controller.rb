class ExploreController < ApplicationController
  VARIANTS = %i[devlog fire certified ship].freeze

  def index
    non_tutorial_devlog_ids = Post::Devlog.where(tutorial: false).select(:id)
    scope = Post.includes(:user, :project, postable: { attachments_attachments: :blob, likes: [] })
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

  def extensions
    min_weekly_users = 2
    one_week_ago = 1.week.ago

    project_ids_with_usage = ExtensionUsage
      .where("recorded_at >= ?", one_week_ago)
      .group(:project_id)
      .having("COUNT(DISTINCT user_id) >= ?", min_weekly_users)
      .order(Arel.sql("COUNT(DISTINCT user_id) DESC"))
      .pluck(:project_id)

    @projects_with_counts = Project
      .where(id: project_ids_with_usage)
      .where.not(shipped_at: nil)
      .includes(banner_attachment: :blob)
      .index_by(&:id)
      .values_at(*project_ids_with_usage)
      .compact

    @weekly_user_counts = ExtensionUsage
      .where(project_id: project_ids_with_usage)
      .where("recorded_at >= ?", one_week_ago)
      .group(:project_id)
      .count("DISTINCT user_id")
  end

  private

  def devlog_variant(post)
    VARIANTS[post.id % VARIANTS.length]
  end
  helper_method :devlog_variant
end
