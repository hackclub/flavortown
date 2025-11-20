class VotesController < ApplicationController
  before_action :authenticate_user!

  def new
    # new vote
    @project = Project.votable_by(current_user).first
  end
end
