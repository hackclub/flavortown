module Admin
  class SidequestEntriesController < Admin::ApplicationController
    before_action :set_entry, only: [ :show, :approve, :reject ]

    def index
      authorize :admin, :access_admin_endpoints?

      # Only show entries for projects that have been shipped (have a ship_event)
      @entries = SidequestEntry
        .joins(project: :ship_events)
        .includes(:sidequest, :reviewed_by, project: :users)
        .distinct
        .order(created_at: :desc)
      @entries = @entries.where(aasm_state: params[:status]) if params[:status].present?
      @entries = @entries.where(sidequest_id: params[:sidequest_id]) if params[:sidequest_id].present?

      shipped_entries = SidequestEntry.joins(project: :ship_events).distinct
      @counts = {
        pending: shipped_entries.pending.count,
        approved: shipped_entries.approved.count,
        rejected: shipped_entries.rejected.count
      }

      @sidequests = Sidequest.all
    end

    def show
      authorize :admin, :access_admin_endpoints?
    end

    def approve
      authorize :admin, :access_admin_endpoints?

      if @entry.may_approve?
        @entry.approve!(current_user)
        redirect_to admin_sidequest_entries_path, notice: "Entry approved! Achievement granted."
      else
        redirect_to admin_sidequest_entries_path, alert: "Cannot approve this entry."
      end
    end

    def reject
      authorize :admin, :access_admin_endpoints?

      if @entry.may_reject?
        @entry.rejection_message = params[:rejection_message].presence
        @entry.is_rejection_fee_charged = params[:charge_fee] == "1"
        @entry.reject!(current_user)
        redirect_to admin_sidequest_entries_path, notice: "Entry rejected."
      else
        redirect_to admin_sidequest_entries_path, alert: "Cannot reject this entry."
      end
    end

    private

    def set_entry
      @entry = SidequestEntry.find(params[:id])
    end
  end
end
