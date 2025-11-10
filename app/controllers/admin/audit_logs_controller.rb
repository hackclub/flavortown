module Admin
  class AuditLogsController < Admin::ApplicationController
    def index
      authorize :admin, :access_admin_endpoints_but_ac_admin?

      @versions = PaperTrail::Version.order(created_at: :desc).limit(50)

      # Apply filters
      if params[:item_type].present?
        @versions = @versions.where(item_type: params[:item_type])
      end

      if params[:event].present?
        @versions = @versions.where(event: params[:event])
      end

      if params[:whodunnit].present?
        @versions = @versions.where(whodunnit: params[:whodunnit])
      end

      if params[:start_date].present?
        @versions = @versions.where("created_at >= ?", params[:start_date])
      end

      if params[:end_date].present?
        @versions = @versions.where("created_at <= ?", params[:end_date])
      end

      # Get unique item types and users for filters
      @item_types = PaperTrail::Version.distinct.pluck(:item_type).compact.sort
      @users = User.where(id: PaperTrail::Version.distinct.pluck(:whodunnit).compact).order(:display_name)
    end

    def show
      authorize :admin, :access_admin_endpoints_but_ac_admin?
      @version = PaperTrail::Version.find(params[:id])
    end
  end
end
