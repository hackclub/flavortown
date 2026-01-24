class KitchenController < ApplicationController
  prepend_before_action :load_current_user_with_identities

  def index
    authorize :kitchen, :index?

    identities = current_user.identities

    unless current_user.verification_verified? && current_user.ysws_eligible == true
      @verification_rejection_reason = refresh_verification_status_from_hca!(identities)
      current_user.reload
      identities = current_user.identities.reload
    end

    @has_hackatime_linked = current_user.has_hackatime?
    @has_identity_linked = current_user.identity_verified?

    CheckSlackMembershipJob.perform_later(current_user) unless current_user.tutorial_step_completed?(:setup_slack)

    @tutorial_steps = User::TutorialStep.all
    @completed_steps = current_user.tutorial_steps
    @tutorial_is_complete = @tutorial_steps - @completed_steps

    @recently_added_items = ShopItem.enabled.buyable_standalone.recently_added.includes(:image_attachment)
    @user_region = determine_user_region
    @user_balance = current_user.balance

    show_from_session = session.delete(:show_welcome_overlay)
    @show_welcome_overlay = show_from_session

    if @show_welcome_overlay
      @show_hackatime_tutorial = !current_user.tutorial_step_completed?(:setup_hackatime)
      @show_slack_tutorial = !current_user.tutorial_step_completed?(:setup_slack)
    else
      @show_hackatime_tutorial = false
      @show_slack_tutorial = false
    end

    @show_flagship_ad = current_user.has_logged_one_hour? && !current_user.has_dismissed?(:flagship_ad)
  end

  private

  def load_current_user_with_identities
    current_user(:identities)
  end

  def determine_user_region
    return current_user.shop_region if current_user.shop_region.present?
    return current_user.regions.first if current_user.has_regions?

    primary_address = current_user.addresses.find { |a| a["primary"] } || current_user.addresses.first
    country = primary_address&.dig("country")
    region_from_address = Shop::Regionalizable.country_to_region(country)
    return region_from_address if region_from_address != "XX" || country.present?

    Shop::Regionalizable.timezone_to_region(cookies[:timezone]) || "US"
  end

  # temp
  def refresh_verification_status_from_hca!(identities)
    identity = identities.find { |i| i.provider == "hack_club" }
    return unless identity&.access_token.present?

    identity_payload = HCAService.identity(identity.access_token)
    return if identity_payload.blank?

    latest_status = identity_payload["verification_status"].to_s
    return unless User.verification_statuses.key?(latest_status)

    ysws_eligible = identity_payload["ysws_eligible"] == true

    current_user.complete_tutorial_step!(:identity_verified) if latest_status == "verified"

    current_user.verification_status = latest_status
    current_user.ysws_eligible = ysws_eligible

    current_user.save!

    {
      "reason" => identity_payload["rejection_reason"],
      "details" => identity_payload["rejection_reason_details"]
    }.compact_blank.presence
  rescue StandardError => e
    Rails.logger.warn("Kitchen HCA refresh failed: #{e.class}: #{e.message}")
    nil
  end
end
