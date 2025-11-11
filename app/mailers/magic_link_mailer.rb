class MagicLinkMailer < ApplicationMailer
  def send_magic_link(user)
    @user = user
    @magic_link_url = magic_links_verify_url(token: user.magic_link_token)
    mail(to: @user.email)
  end
end
