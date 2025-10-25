class LoginMailer < ApplicationMailer
  def signin_notification
    @user = params[:user]
    # The "to" address is required by Action Mailer but will be overwritten
    # by the email provided in the view. A subject is also not required here
    # as Loops will use the subject from the editor.
    mail(to: @user.email)
  end
end
