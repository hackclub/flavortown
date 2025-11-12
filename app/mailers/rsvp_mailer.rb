class RsvpMailer < ApplicationMailer
  def signup_confirmation(email, magic_link_url: nil)
    @email = email
    @magic_link_url = magic_link_url
    # The "to" address is required by Action Mailer but will be overwritten
    # by the email provided in the view. A subject is also not required here
    # as Loops will use the subject from the editor.
    mail(to: @email)
  end
end
