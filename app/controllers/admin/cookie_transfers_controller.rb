module Admin
  class CookieTransfersController < ApplicationController
    before_action :set_paper_trail_whodunnit

    def index
      authorize :admin, :access_cookie_transfers?

      @transfers = CookieTransfer.includes(:sender, :recipient, :reviewed_by)

      if params[:status].present?
        @transfers = @transfers.where(aasm_state: params[:status])
      end

      if params[:user_search].present?
        search = "%#{ActiveRecord::Base.sanitize_sql_like(params[:user_search])}%"
        @transfers = @transfers.joins("LEFT JOIN users AS senders ON senders.id = cookie_transfers.sender_id")
                               .joins("LEFT JOIN users AS recipients ON recipients.id = cookie_transfers.recipient_id")
                               .where("senders.display_name ILIKE ? OR recipients.display_name ILIKE ?", search, search)
      end

      @transfers = @transfers.order(created_at: :desc)

      @counts = {
        pending: CookieTransfer.where(aasm_state: "pending").count,
        approved: CookieTransfer.where(aasm_state: "approved").count,
        rejected: CookieTransfer.where(aasm_state: "rejected").count
      }
    end

    def show
      authorize :admin, :access_cookie_transfers?
      @transfer = CookieTransfer.includes(:sender, :recipient, :reviewed_by).find(params[:id])

      @sender_transfers = CookieTransfer.where(sender: @transfer.sender).where.not(id: @transfer.id).order(created_at: :desc).limit(5)
      @recipient_transfers = CookieTransfer.where(recipient: @transfer.recipient).where.not(id: @transfer.id).order(created_at: :desc).limit(5)
    end

    def approve
      authorize :admin, :access_cookie_transfers?
      @transfer = CookieTransfer.find(params[:id])

      if @transfer.sender.balance < @transfer.amount
        redirect_to admin_cookie_transfer_path(@transfer), alert: "Sender no longer has sufficient balance (#{@transfer.sender.balance} cookies)" and return
      end

      @transfer.reviewed_by = current_user
      @transfer.reviewed_at = Time.current

      if @transfer.approve && @transfer.save
        redirect_to admin_cookie_transfers_path, notice: "Transfer approved"
      else
        redirect_to admin_cookie_transfer_path(@transfer), alert: "Failed to approve transfer: #{@transfer.errors.full_messages.join(', ')}"
      end
    end

    def reject
      authorize :admin, :access_cookie_transfers?
      @transfer = CookieTransfer.find(params[:id])
      reason = params[:reason].presence || "No reason provided"

      @transfer.reviewed_by = current_user
      @transfer.reviewed_at = Time.current

      if @transfer.reject(reason) && @transfer.save
        redirect_to admin_cookie_transfers_path, notice: "Transfer rejected"
      else
        redirect_to admin_cookie_transfer_path(@transfer), alert: "Failed to reject transfer: #{@transfer.errors.full_messages.join(', ')}"
      end
    end
  end
end
