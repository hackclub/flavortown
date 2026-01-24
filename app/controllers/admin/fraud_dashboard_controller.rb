module Admin
  class FraudDashboardController < ApplicationController
    def index
      authorize :admin, :access_fraud_dashboard?
      today = Time.current.beginning_of_day..Time.current.end_of_day

      s = Project::Report.group(:status).count
      report_versions = versions_today("Project::Report", "status", today)
      @reports = {
        pending: s["pending"] || 0, reviewed: s["reviewed"] || 0, dismissed: s["dismissed"] || 0,
        new_today: Project::Report.where(created_at: today).count,
        reasons: Project::Report.group(:reason).count,
        by_status: { pending: s["pending"] || 0, reviewed: s["reviewed"] || 0, dismissed: s["dismissed"] || 0 },
        top_reviewers: top_performers(report_versions, "status", %w[reviewed dismissed]),
        avg_response_hours: avg_response("project_reports", "Project::Report", "status", %w[reviewed dismissed])
      }

      # Ban stats
      bc = User.where("banned = ? OR shadow_banned = ?", true, true).group(:banned, :shadow_banned).count
      @bans = {
        banned: bc.sum { |(b, _), c| b ? c : 0 },
        shadow_banned_users: bc.sum { |(_, sb), c| sb ? c : 0 },
        shadow_banned_projects: Project.where(shadow_banned: true).count,
        bans_today: changes_count("User", "banned", true, today),
        unbans_today: changes_count("User", "banned", false, today),
        shadow_bans_today: changes_count("User", "shadow_banned", true, today),
        unshadow_bans_today: changes_count("User", "shadow_banned", false, today),
        project_shadow_today: changes_count("Project", "shadow_banned", true, today),
        project_unshadow_today: changes_count("Project", "shadow_banned", false, today)
      }

      # Order stats
      o = ShopOrder.group(:aasm_state).count
      pending, awaiting = o["pending"] || 0, o["awaiting_periodical_fulfillment"] || 0
      order_versions = versions_today("ShopOrder", "aasm_state", today)
      order_states = %w[awaiting_periodical_fulfillment rejected on_hold fulfilled]
      @orders = {
        pending: pending, on_hold: o["on_hold"] || 0, rejected: o["rejected"] || 0,
        awaiting: awaiting, backlog: pending + awaiting,
        new_today: ShopOrder.where(created_at: today).count,
        top_reviewers: top_performers(order_versions, "aasm_state", order_states),
        all_time: all_time_performers(order_states),
        avg_response_hours: avg_response("shop_orders", "ShopOrder", "aasm_state", %w[awaiting_periodical_fulfillment rejected fulfilled])
      }
    end

    private

    def versions_today(type, field, today)
      PaperTrail::Version.where(item_type: type, created_at: today)
        .where.not(whodunnit: nil).where("jsonb_exists(object_changes, ?)", field).to_a
    end

    def changes_count(type, field, val, today)
      json_val = val.is_a?(String) ? "\"#{val}\"" : val.to_s
      PaperTrail::Version.where(item_type: type, created_at: today)
        .where("object_changes -> ? ->> 1 = ?", field, json_val).count
    end

    def top_performers(versions, field, states, limit = 3)
      counts = versions.each_with_object(Hash.new(0)) do |v, h|
        uid = v.whodunnit.to_i
        next if uid.zero?
        arr = (v.object_changes || {})[field]
        h[uid] += 1 if arr.is_a?(Array) && arr.length == 2 && states.include?(arr[1])
      end
      ids = counts.sort_by { |_, c| -c }.first(limit).map(&:first)
      users = User.where(id: ids).select(:id, :display_name).index_by(&:id)
      ids.map { |id| { name: users[id]&.display_name || "User ##{id}", count: counts[id] } }
    end

    def all_time_performers(states)
      counts = PaperTrail::Version.where(item_type: "ShopOrder").where.not(whodunnit: nil)
        .where("jsonb_exists(object_changes, ?)", "aasm_state")
        .where("object_changes -> 'aasm_state' ->> 1 IN (?)", states).group(:whodunnit).count
      sorted = counts.sort_by { |_, c| -c }.first(10)
      ids = sorted.map { |k, _| k.to_i }
      users = User.where(id: ids).select(:id, :display_name).index_by(&:id)
      sorted.map { |k, c| { name: users[k.to_i]&.display_name || "User ##{k}", count: c } }
    end

    TABLES = %w[project_reports shop_orders].freeze
    FIELDS = %w[status aasm_state].freeze
    TYPES = %w[Project::Report ShopOrder].freeze
    def avg_response(table, type, field, states)
      raise ArgumentError unless TABLES.include?(table) && FIELDS.include?(field) && TYPES.include?(type)
      quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
      quoted_field = ActiveRecord::Base.connection.quote_column_name(field)

      sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, states, type, field, field, states ])
        SELECT AVG(EXTRACT(EPOCH FROM (v.v_at - r.r_at)) / 3600.0) AS avg_hours
        FROM (
          SELECT r.id, r.created_at AS r_at
          FROM #{quoted_table} r
          WHERE r.#{quoted_field} = ANY (?)
            AND r.created_at > NOW() - INTERVAL '30 days'
          ORDER BY r.created_at DESC
          LIMIT 100
        ) r
        JOIN LATERAL (
          SELECT v.created_at AS v_at
          FROM versions v
          WHERE v.item_type = ?
            AND v.item_id = r.id
            AND jsonb_exists(v.object_changes, ?)
            AND v.created_at >= r.r_at
            AND (v.object_changes -> ? ->> 1) = ANY (?)
          ORDER BY v.created_at ASC
          LIMIT 1
        ) v ON true
      SQL
      ActiveRecord::Base.connection.select_one(sql)&.dig("avg_hours")&.to_f&.round(1)
    end
  end
end
