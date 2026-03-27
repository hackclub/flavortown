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

    if @sidequest.slug.in?(%w[webos optimization lockin])
      @prizes = ShopItem.where(requires_achievement: "sidequest_#{@sidequest.slug}", enabled: true)
    end

    custom_template = "sidequests/show_#{@sidequest.slug}"
    if lookup_context.exists?(custom_template)
      render custom_template
    end
  end
end
