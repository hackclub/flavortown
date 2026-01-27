class User::TutorialStepsController < ApplicationController
  before_action :set_tutorial_step, only: [ :show ]

  def show
    redirect_to @tutorial_step.link, allow_other_host: true
  end

  def complete
    current_user.complete_tutorial_step!(params[:id].to_sym)

    respond_to do |format|
      format.turbo_stream do
        @tutorial_steps = User::TutorialStep.all
        @completed_steps = current_user.tutorial_steps
        render turbo_stream: turbo_stream.replace(
          "tutorial-steps-container",
          KitchenTutorialStepsComponent.new(
            tutorial_steps: @tutorial_steps,
            completed_steps: @completed_steps,
            current_user: current_user
          )
        )
      end
      format.json { head :ok }
      format.html { head :ok }
    end
  end

  private

  def set_tutorial_step
    @tutorial_step = User::TutorialStep.find(params[:id].to_sym)
    raise ActiveRecord::RecordNotFound if @tutorial_step.nil?
  end
end
