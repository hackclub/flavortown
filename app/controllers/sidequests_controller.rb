class SidequestsController < ApplicationController
  def index
    @active_sidequests = Sidequest.active.with_approved_count
    @expired_sidequests = Sidequest.expired.with_approved_count
  end

  def show
    @sidequest = Sidequest.find_by!(slug: params[:id])

    if @sidequest.external_page_link.present?
      redirect_to @sidequest.external_page_link, allow_other_host: true and return
    end

    @approved_entries = @sidequest.sidequest_entries
      .approved
      .joins(:project)
      .includes(project: :memberships)
    if @sidequest.slug == "webos"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_webos").where(enabled: true)
    end

    if @sidequest.slug == "optimization"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_optimization").where(enabled: true)
    end

    if @sidequest.slug == "lockin"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_lockin").where(enabled: true)
    end

    if @sidequest.slug == "roastedapples"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_roastedapples").where(enabled: true)
    end

    custom_template = "sidequests/show_#{@sidequest.slug}"
    if lookup_context.exists?(custom_template)
      render custom_template
    end
  end
end
