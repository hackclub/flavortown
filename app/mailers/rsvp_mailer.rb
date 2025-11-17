class RsvpMailer < ApplicationMailer
  def signup_confirmation(email)
    @email = email
    # The "to" address is required by Action Mailer but will be overwritten
    # by the email provided in the view. A subject is also not required here
    # as Loops will use the subject from the editor.
    mail(to: @email)
  end
end
