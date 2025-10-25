class SetRsvpInLoopsJob < ApplicationJob
  queue_as :literally_whenever

  def perform(email)
    result = LoopsService.set_event(email, "FlavortownRsvpAt")
    
    if result[:error]
      Rails.logger.error "Failed to set RSVP event in Loops for #{email}: #{result[:error]}"
    else
      Rails.logger.info "Successfully set RSVP event in Loops for #{email}"
    end
  end
end
