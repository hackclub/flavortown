class ExploreController < ApplicationController
  VARIANTS = %i[devlog fire certified ship].freeze

  def index
    scope = Post.includes(:user, :project, postable: { attachments_attachments: :blob })
                .where(postable_type: "Post::Devlog")
                .where.not(user_id: current_user.id)
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
                    .order(created_at: :desc)

    @pagy, @projects = pagy(scope)

    respond_to do |format|
      format.html
      format.json do
        html = @projects.map do |project|
          render_to_string(
            ProjectCardComponent.new(project: project),
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
