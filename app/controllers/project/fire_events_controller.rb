class Project::FireEventsController < ApplicationController
  before_action -> { authorize :admin }
  before_action :set_project!

  def create
    if @project.fire?
      return render json: { message: "Project is already marked as 🔥" }, status: :unprocessable_entity
    end

    fire_event = Post::FireEvent.new(body: "🔥 #{current_user.display_name} marked your project as well cooked! As a prize for your nicely cooked project, look out for a bonus prize in the mail :)")
    post = @project.posts.build(user: current_user, postable: fire_event)

    PaperTrail.request(whodunnit: current_user.id) do
      unless post.save
        errors = (post.errors.full_messages + fire_event.errors.full_messages).uniq
        return render json: { message: errors.to_sentence.presence || "Failed to mark project as 🔥" }, status: :unprocessable_entity
      end

      @project.mark_fire!(current_user)
      log_version!("mark_fire", marked_fire_by_id: current_user.id, created_post_id: post.id)
    end

    Project::PostToMagicJob.perform_later(@project)
    Project::MagicHappeningLetterJob.perform_later(@project)
    render json: { message: "Project marked as 🔥!", fire: true }
  end

  def destroy
    PaperTrail.request(whodunnit: current_user.id) do
      @project.unmark_fire!
      log_version!("unmark_fire")
    end
    render json: { message: "Project unmarked as 🔥", fire: false }
  end

  private

  def set_project!
    @project = Project.find_by(id: params[:project_id])
    render json: { message: "Project not found" }, status: :not_found unless @project
  end

  def log_version!(event, changes = {})
    PaperTrail::Version.create!(
      item_type: "Project", item_id: @project.id, event: event, whodunnit: current_user.id,
      object_changes: { admin_action: [ nil, event ], **changes.transform_values { [ nil, _1 ] } }
    )
  end
end
  