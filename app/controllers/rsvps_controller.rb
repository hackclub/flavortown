class RsvpsController < ApplicationController
  def create
    @rsvp = Rsvp.new(email: params[:rsvp][:email].downcase.strip)

    respond_to do |format|
      if @rsvp.save
        @success_message = "We just sent an email - check your inbox!"
        format.turbo_stream { render :create }
        format.html { redirect_to root_path, notice: @success_message }
      else
        @error_message = "Please enter a valid email address."
        format.turbo_stream { render :create }
        format.html { redirect_to root_path, alert: @error_message }
      end
    end
  end
end
