class Project::DevlogsController < ApplicationController
  before_action :set_project

  def new
    @devlog = Post::Devlog.new
  end

  def create
    @devlog = Post::Devlog.new(devlog_params)

    if @devlog.save
      Post.create!(project: @project, user: current_user, postable: @devlog)
      flash[:notice] = "Devlog created successfully"
      current_user.complete_tutorial_step! :post_devlog
      redirect_to @project
    else
      flash.now[:alert] = @devlog.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def devlog_params
    params.require(:post_devlog).permit(:body, attachments: [])
  end
end
