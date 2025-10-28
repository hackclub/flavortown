class ProjectIdeasController < ApplicationController
  def random
    load_message = FlavortextService.project_ideas("loading_messages")
    @project_idea = OpenaiProjectIdeasService.generate

    render json: {
      idea: @project_idea.content,
      load_message: load_message
    }
  end
end
