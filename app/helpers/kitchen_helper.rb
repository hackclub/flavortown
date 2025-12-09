module KitchenHelper
  def id_verification_ui_for(user)
    return { variant: :danger, badge: "Unknown" } unless user

    if user.verification_needs_submission?
      { variant: :danger, badge: "Needs submission" }
    elsif user.verification_pending?
      { variant: :warning, badge: "Under Review" }
    elsif user.verification_verified?
      { variant: :success, badge: "Verified" }
    elsif user.verification_ineligible?
      { variant: :danger, badge: "Ineligible" }
    else
      { variant: :danger, badge: "Unknown" }
    end
  end
end
