module Admin
  class FraudDashboardController < ApplicationController
    def index
      authorize :admin, :access_fraud_dashboard?
      @today = Time.current.beginning_of_day..Time.current.end_of_day
      generate_report_stats
      generate_ban_stats
      generate_order_stats
    end

    private

    def generate_report_stats
      @reports = {
        pending: Project::Report.pending.count,
        reviewed: Project::Report.reviewed.count,
        dismissed: Project::Report.dismissed.count,
        new_today: Project::Report.where(created_at: @today).count,
        reasons: Project::Report.group(:reason).count
      }
      @reports[:by_status] = {
        pending: @reports[:pending],
        reviewed: @reports[:reviewed],
        dismissed: @reports[:dismissed]
      }

      versions = PaperTrail::Version
        .where(item_type: "Project::Report", created_at: @today)
        .where.not(whodunnit: nil)
        .where("jsonb_exists(object_changes, ?)", "status")
      @reports[:top_reviewers] = top_performers(versions, "status", %w[reviewed dismissed])
      @reports[:avg_response_hours] = avg_response_reports
    end

    def generate_ban_stats
      @bans = {
        banned: User.where(banned: true).count,
        shadow_banned_users: User.where(shadow_banned: true).count,
        shadow_banned_projects: Project.where(shadow_banned: true).count
      }

      ban_versions = user_versions_for_field("banned")
      shadow_versions = user_versions_for_field("shadow_banned")
      project_shadow = project_versions_for_field("shadow_banned")

      @bans[:bans_today] = count_changes(ban_versions, "banned", true)
      @bans[:unbans_today] = count_changes(ban_versions, "banned", false)
      @bans[:shadow_bans_today] = count_changes(shadow_versions, "shadow_banned", true)
      @bans[:unshadow_bans_today] = count_changes(shadow_versions, "shadow_banned", false)
      @bans[:project_shadow_today] = count_changes(project_shadow, "shadow_banned", true)
      @bans[:project_unshadow_today] = count_changes(project_shadow, "shadow_banned", false)
    end

    def generate_order_stats
      states = ShopOrder.group(:aasm_state).count
      pending = states["pending"] || 0
      awaiting = states["awaiting_periodical_fulfillment"] || 0

      @orders = {
        pending: pending,
        on_hold: states["on_hold"] || 0,
        rejected: states["rejected"] || 0,
        awaiting: awaiting,
        backlog: pending + awaiting,
        new_today: ShopOrder.where(created_at: @today).count
      }

      versions = PaperTrail::Version
        .where(item_type: "ShopOrder", created_at: @today)
        .where.not(whodunnit: nil)
        .where("jsonb_exists(object_changes, ?)", "aasm_state")
      @orders[:top_reviewers] = top_performers(versions, "aasm_state", %w[awaiting_periodical_fulfillment rejected on_hold fulfilled])

      all_versions = PaperTrail::Version
        .where(item_type: "ShopOrder")
        .where.not(whodunnit: nil)
        .where("jsonb_exists(object_changes, ?)", "aasm_state")
      @orders[:all_time] = top_performers(all_versions, "aasm_state", %w[awaiting_periodical_fulfillment rejected on_hold fulfilled], 10)
      @orders[:avg_response_hours] = avg_response_orders
    end

    def top_performers(versions, field, valid_states, limit = 3)
      counts = versions.each_with_object(Hash.new(0)) do |v, h|
        uid = v.whodunnit.to_i
        next if uid.zero?
        changes = v.object_changes || {}
        arr = changes[field]
        next unless arr.is_a?(Array) && arr.length == 2 && valid_states.include?(arr[1])
        h[uid] += 1
      end

      ids = counts.sort_by { |_, c| -c }.first(limit).map(&:first)
      users = User.where(id: ids).index_by(&:id)
      ids.map { |id| { name: users[id]&.display_name || "User ##{id}", count: counts[id] } }
    end

    def user_versions_for_field(field)
      PaperTrail::Version.where(item_type: "User", created_at: @today).where("jsonb_exists(object_changes, ?)", field)
    end

    def project_versions_for_field(field)
      PaperTrail::Version.where(item_type: "Project", created_at: @today).where("jsonb_exists(object_changes, ?)", field)
    end

    def count_changes(versions, field, target_value)
      versions.count do |v|
        arr = (v.object_changes || {})[field]
        arr.is_a?(Array) && arr.length == 2 && arr[1] == target_value
      end
    end

    def avg_response_reports
      reports = Project::Report.where(status: %w[reviewed dismissed]).where("created_at > ?", 30.days.ago).limit(100)
      return nil if reports.empty?

      total = reports.sum do |r|
        v = PaperTrail::Version.where(item_type: "Project::Report", item_id: r.id)
                               .where("jsonb_exists(object_changes, ?)", "status").order(:created_at).first
        v ? (v.created_at - r.created_at) / 1.hour : 0
      end
      (total / reports.count).round(1)
    end

    def avg_response_orders
      orders = ShopOrder.where(aasm_state: %w[awaiting_periodical_fulfillment rejected fulfilled])
                        .where("created_at > ?", 30.days.ago).limit(100)
      return nil if orders.empty?

      total = orders.sum do |o|
        v = o.versions.find { |ver| ver.object_changes&.dig("aasm_state")&.last.in?(%w[awaiting_periodical_fulfillment rejected]) }
        v ? (v.created_at - o.created_at) / 1.hour : 0
      end
      (total / orders.count).round(1)
    end
  end
end
