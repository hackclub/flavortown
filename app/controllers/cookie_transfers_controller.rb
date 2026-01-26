class CookieTransfersController < ApplicationController
  before_action :require_login
  before_action :require_feature_enabled
  before_action :require_verified_sender, only: [ :new, :create ]

  def new
    authorize CookieTransfer
    @cookie_transfer = CookieTransfer.new
  end

  def create
    authorize CookieTransfer
    @cookie_transfer = CookieTransfer.new(cookie_transfer_params)
    @cookie_transfer.sender = current_user

    if @cookie_transfer.save
      flash[:notice] = "Your transfer of #{@cookie_transfer.amount} cookies to #{@cookie_transfer.recipient.display_name} is pending approval."
      redirect_to my_balance_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_login
    unless current_user
      flash[:alert] = "Please log in to transfer cookies."
      redirect_to root_path
    end
  end

  def require_feature_enabled
    unless Flipper.enabled?(:cookie_transfers, current_user)
      flash[:alert] = "Cookie transfers are not available yet."
      redirect_to root_path
    end
  end

  def require_verified_sender
    unless current_user.verification_verified?
      flash[:alert] = "You must complete identity verification to transfer cookies."
      redirect_to my_balance_path
    end
  end

  def cookie_transfer_params
    params.require(:cookie_transfer).permit(:recipient_id, :amount, :note)
  end
end
