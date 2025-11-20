module KitchenHelper
  def id_verification_ui_for(user)
    status = user&.verification_status.to_s
    case status
    when "needs_submission"
      { variant: :danger, badge: "Needs submission" }
    when "pending"
      { variant: :warning, badge: "Under Review" }
    when "verified"
      { variant: :success, badge: "Verified" }
    when "ineligible"
      { variant: :danger, badge: "Ineligible" }
    else
      { variant: :danger, badge: "Unknown" }
    end
  end
end
