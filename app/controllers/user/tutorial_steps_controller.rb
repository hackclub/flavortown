class User::TutorialStepsController < ApplicationController
  before_action :set_tutorial_step, only: [ :show ]

  def show
    redirect_to @tutorial_step.link
  end

  private

  def set_tutorial_step
    @tutorial_step = User::TutorialStep.find(params[:id].to_sym)
    raise ActiveRecord::RecordNotFound if @tutorial_step.nil?
  end
end
