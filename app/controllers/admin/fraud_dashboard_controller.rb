module Admin
  class FraudDashboardController < ApplicationController
    def index
      authorize :admin, :access_fraud_dashboard?
      today = Time.current.beginning_of_day..Time.current.end_of_day

      # Single query for all report stats
      report_stats_sql = Project::Report.sanitize_sql_array([
        "SELECT COUNT(*) FILTER (WHERE status = 0) AS pending_count,
                COUNT(*) FILTER (WHERE status = 1) AS reviewed_count,
                COUNT(*) FILTER (WHERE status = 2) AS dismissed_count,
                COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS new_today
         FROM project_reports", today.begin, today.end
      ])
      rs = ActiveRecord::Base.connection.select_one(report_stats_sql)

      reasons = Project::Report.group(:reason).count

      @reports = {
        pending: rs["pending_count"].to_i,
        reviewed: rs["reviewed_count"].to_i,
        dismissed: rs["dismissed_count"].to_i,
        new_today: rs["new_today"].to_i,
        reasons: reasons,
        by_status: { pending: rs["pending_count"].to_i, reviewed: rs["reviewed_count"].to_i, dismissed: rs["dismissed_count"].to_i },
        top_reviewers: all_time_report_performers(%w[reviewed dismissed]),
        avg_response_hours: avg_response("project_reports", "Project::Report", "status", %w[reviewed dismissed])
      }

      # Single query for ban stats
      ban_stats_sql = <<~SQL
        SELECT
          COUNT(*) FILTER (WHERE banned = true) AS banned_count,
          COUNT(*) FILTER (WHERE shadow_banned = true) AS shadow_banned_count
        FROM users
        WHERE banned = true OR shadow_banned = true
      SQL
      bs = ActiveRecord::Base.connection.select_one(ban_stats_sql)

      shadow_project_count = Project.where(shadow_banned: true).count

      # Single query for all version-based ban changes today
      ban_changes = batch_changes_count(today)

      @bans = {
        banned: bs["banned_count"].to_i,
        shadow_banned_users: bs["shadow_banned_count"].to_i,
        shadow_banned_projects: shadow_project_count,
        bans_today: ban_changes.dig("User", "banned", "true") || 0,
        unbans_today: ban_changes.dig("User", "banned", "false") || 0,
        shadow_bans_today: ban_changes.dig("User", "shadow_banned", "true") || 0,
        unshadow_bans_today: ban_changes.dig("User", "shadow_banned", "false") || 0,
        project_shadow_today: ban_changes.dig("Project", "shadow_banned", "true") || 0,
        project_unshadow_today: ban_changes.dig("Project", "shadow_banned", "false") || 0
      }

      # Single query for order stats
      order_stats_sql = Project::Report.sanitize_sql_array([
        "SELECT COUNT(*) FILTER (WHERE aasm_state = 'pending') AS pending_count,
                COUNT(*) FILTER (WHERE aasm_state = 'on_hold') AS on_hold_count,
                COUNT(*) FILTER (WHERE aasm_state = 'rejected') AS rejected_count,
                COUNT(*) FILTER (WHERE aasm_state = 'awaiting_periodical_fulfillment') AS awaiting_count,
                COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS new_today
         FROM shop_orders", today.begin, today.end
      ])
      os = ActiveRecord::Base.connection.select_one(order_stats_sql)

      order_states = %w[awaiting_periodical_fulfillment rejected on_hold fulfilled]

      @orders = {
        pending: os["pending_count"].to_i,
        on_hold: os["on_hold_count"].to_i,
        rejected: os["rejected_count"].to_i,
        awaiting: os["awaiting_count"].to_i,
        backlog: os["pending_count"].to_i + os["awaiting_count"].to_i,
        new_today: os["new_today"].to_i,
        top_reviewers: all_time_performers(order_states),
        avg_response_hours: avg_response("shop_orders", "ShopOrder", "aasm_state", %w[awaiting_periodical_fulfillment rejected fulfilled])
      }
    end

    private

    def batch_changes_count(today)
      sql = PaperTrail::Version.sanitize_sql_array([
        "SELECT item_type,
                CASE
                  WHEN jsonb_exists(object_changes, 'banned') THEN 'banned'
                  WHEN jsonb_exists(object_changes, 'shadow_banned') THEN 'shadow_banned'
                END AS field,
                CASE
                  WHEN jsonb_exists(object_changes, 'banned') THEN object_changes -> 'banned' ->> 1
                  WHEN jsonb_exists(object_changes, 'shadow_banned') THEN object_changes -> 'shadow_banned' ->> 1
                END AS new_value,
                COUNT(*) AS cnt
         FROM versions
         WHERE item_type IN ('User', 'Project')
           AND created_at >= ? AND created_at <= ?
           AND (jsonb_exists(object_changes, 'banned') OR jsonb_exists(object_changes, 'shadow_banned'))
         GROUP BY item_type, field, new_value",
        today.begin, today.end
      ])

      result = {}
      ActiveRecord::Base.connection.select_all(sql).each do |row|
        result[row["item_type"]] ||= {}
        result[row["item_type"]][row["field"]] ||= {}
        result[row["item_type"]][row["field"]][row["new_value"]] = row["cnt"].to_i
      end
      result
    end

    def all_time_performers(states)
      pg_array = "{#{states.join(',')}}"
      sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, pg_array ])
        SELECT whodunnit, COUNT(*) AS cnt
        FROM versions
        WHERE item_type = 'ShopOrder'
          AND whodunnit IS NOT NULL
          AND jsonb_exists(object_changes, 'aasm_state')
          AND (object_changes -> 'aasm_state' ->> 1) = ANY (?::text[])
        GROUP BY whodunnit
        ORDER BY cnt DESC
        LIMIT 10
      SQL

      rows = ActiveRecord::Base.connection.select_all(sql).to_a
      ids = rows.map { |r| r["whodunnit"].to_i }
      return [] if ids.empty?

      users = User.where(id: ids).select(:id, :display_name).index_by(&:id)
      rows.map { |r| { name: users[r["whodunnit"].to_i]&.display_name || "User ##{r["whodunnit"]}", count: r["cnt"].to_i } }
    end

    def all_time_report_performers(states)
      pg_array = "{#{states.join(',')}}"
      sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, pg_array ])
        SELECT whodunnit, COUNT(*) AS cnt
        FROM versions
        WHERE item_type = 'Project::Report'
          AND whodunnit IS NOT NULL
          AND jsonb_exists(object_changes, 'status')
          AND (object_changes -> 'status' ->> 1) = ANY (?::text[])
        GROUP BY whodunnit
        ORDER BY cnt DESC
        LIMIT 10
      SQL

      rows = ActiveRecord::Base.connection.select_all(sql).to_a
      ids = rows.map { |r| r["whodunnit"].to_i }
      return [] if ids.empty?

      users = User.where(id: ids).select(:id, :display_name).index_by(&:id)
      rows.map { |r| { name: users[r["whodunnit"].to_i]&.display_name || "User ##{r["whodunnit"]}", count: r["cnt"].to_i } }
    end

    TABLES = %w[project_reports shop_orders].freeze
    FIELDS = %w[status aasm_state].freeze
    TYPES = %w[Project::Report ShopOrder].freeze

    def avg_response(table, type, field, states)
      raise ArgumentError unless TABLES.include?(table) && FIELDS.include?(field) && TYPES.include?(type)
      quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
      quoted_field = ActiveRecord::Base.connection.quote_column_name(field)

      db_values = if table == "project_reports" && field == "status"
                    states.map { |s| Project::Report.statuses.fetch(s) }
      else
                    states
      end

      record_cast = (table == "project_reports" && field == "status") ? "int[]" : "text[]"
      record_pg_array = "{#{db_values.join(',')}}"
      version_pg_array = "{#{db_values.map(&:to_s).join(',')}}"

      sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, record_pg_array, type, field, field, version_pg_array ])
        SELECT AVG(EXTRACT(EPOCH FROM (v.v_at - r.r_at)) / 3600.0) AS avg_hours
        FROM (
          SELECT r.id, r.created_at AS r_at
          FROM #{quoted_table} r
          WHERE r.#{quoted_field} = ANY (?::#{record_cast})
            AND r.created_at > NOW() - INTERVAL '30 days'
          ORDER BY r.created_at DESC
          LIMIT 100
        ) r
        JOIN LATERAL (
          SELECT v.created_at AS v_at
          FROM versions v
          WHERE v.item_type = ?
            AND v.item_id = r.id::text
            AND jsonb_exists(v.object_changes, ?)
            AND v.created_at >= r.r_at
            AND (v.object_changes -> ? ->> 1) = ANY (?::text[])
          ORDER BY v.created_at ASC
          LIMIT 1
        ) v ON true
      SQL
      ActiveRecord::Base.connection.select_one(sql)&.dig("avg_hours")&.to_f&.round(1)
    end
  end
end
