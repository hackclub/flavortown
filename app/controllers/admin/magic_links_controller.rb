class Admin::MagicLinksController < Admin::ApplicationController
  before_action :authenticate_admin

  def show
    authorize :admin, :generate_magic_links?
    @user = User.find(params[:user_id])

    PaperTrail.request(whodunnit: current_user.id) do
      @user.generate_magic_link_token!
    end

    @magic_link_url = magic_links_verify_url(token: @user.magic_link_token)

    respond_to do |format|
      format.html
      format.json { render json: { magic_link: @magic_link_url, expires_at: @user.magic_link_token_expires_at } }
    end
  end
end
