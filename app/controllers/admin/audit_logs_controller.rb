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

    # Map of allowed item types to their classes for safe lookup
    ALLOWED_ITEM_CLASSES = {
      "User" => User,
      "Project" => Project,
      "ShopOrder" => ShopOrder,
      "ShopItem" => ShopItem,
      "Post" => Post,
      "Post::Devlog" => Post::Devlog,
      "Post::ShipEvent" => Post::ShipEvent,
      "Comment" => Comment,
      "LedgerEntry" => LedgerEntry
    }.freeze

    def find_affected_record
      return nil unless params[:item_type].present? && params[:item_id].present?

      klass = ALLOWED_ITEM_CLASSES[params[:item_type]]
      return nil unless klass

      klass.find_by(id: params[:item_id])
    rescue StandardError
      nil
    end
  end
end
