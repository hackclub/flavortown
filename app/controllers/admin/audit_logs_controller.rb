module Admin
  class AuditLogsController < Admin::ApplicationController
    def index
      authorize :admin, :access_audit_logs?

      @versions = PaperTrail::Version.order(created_at: :desc)

      # Hide system activities by default (where whodunnit is nil)
      @show_system = params[:show_system] == "1"
      unless @show_system
        @versions = @versions.where.not(whodunnit: nil)
      end

      # Apply filters
      if params[:item_type].present?
        @versions = @versions.where(item_type: params[:item_type])
      end

      if params[:item_id].present?
        @versions = @versions.where(item_id: params[:item_id])
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

      # Text search in object_changes
      if params[:search].present?
        @versions = @versions.where("object_changes::text ILIKE ?", "%#{params[:search]}%")
      end

      # Pagination
      @pagy, @versions = pagy(:offset, @versions, limit: 50)

      # Get unique item types and users for filters
      @item_types = PaperTrail::Version.distinct.pluck(:item_type).compact.sort
      @users = User.where(id: PaperTrail::Version.distinct.pluck(:whodunnit).compact).order(:display_name)

      # For item_id filter, show the affected record info
      @affected_record = find_affected_record if params[:item_id].present? && params[:item_type].present?
    end

    def show
      authorize :admin, :access_audit_logs?
      @version = PaperTrail::Version.find(params[:id])
    end

    private

    # Only allow looking up records for known audited models
    ALLOWED_ITEM_TYPES = %w[
      User Project ShopOrder ShopItem Post Post::Devlog Post::ShipEvent
      Comment LedgerEntry ProjectMembership
    ].freeze

    def find_affected_record
      return nil unless params[:item_type].present? && params[:item_id].present?
      return nil unless params[:item_type].in?(ALLOWED_ITEM_TYPES)

      klass = params[:item_type].constantize
      klass.find_by(id: params[:item_id])
    rescue NameError, StandardError
      nil
    end
  end
end
