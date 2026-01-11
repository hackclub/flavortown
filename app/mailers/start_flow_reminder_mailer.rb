class StartFlowReminderMailer < ApplicationMailer
  def signin_reminder(email)
    @email = email
    mail(to: @email)
  end
end
