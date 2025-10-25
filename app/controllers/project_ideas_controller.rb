class ProjectIdeasController < ApplicationController
  def random
    @idea = FlavortextService.project_ideas("example_projects")

    if turbo_frame_request?
      render turbo_stream: turbo_stream.replace("project-idea-content", partial: "project_ideas/idea_card", locals: { idea: @idea })
    else
      render json: { idea: @idea }
    end
  end
end
