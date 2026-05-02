# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    module MiscStats
      extend ActiveSupport::Concern

      included do
        helper_method :balance_color_class
      end

      private

      def load_payouts_stats
        cached_data = Rails.cache.fetch("super_mega_payouts", expires_in: 10.minutes) do
          total_distributed_cookies = LedgerEntry.where("amount > 0").sum(:amount)
          used_cookies = LedgerEntry.where("amount < 0").sum(:amount).abs
          cookie_utilization_percentage = ((used_cookies.to_f / total_distributed_cookies) * 100).round(2)

          total_approved_ysws_db_hours = fetch_approved_ysws_db_hours

          transaction_data = build_transaction_data
          hcb_expenses = transaction_data[:total_expenses]

          if total_approved_ysws_db_hours > 0
            dollars_per_hour = (total_distributed_cookies / 5) / total_approved_ysws_db_hours
            expenses_dollars_per_hour = hcb_expenses / total_approved_ysws_db_hours
          else
            dollars_per_hour = 0
            expenses_dollars_per_hour = 0
          end

          {
            cookie_utilization_percentage: cookie_utilization_percentage,
            dollars_per_hour: dollars_per_hour,
            expenses_dollars_per_hour: expenses_dollars_per_hour
          }
        end

        @dollars_per_hour = cached_data&.dig(:dollars_per_hour) || 0
        @expenses_dollars_per_hour = cached_data&.dig(:expenses_dollars_per_hour) || 0
        @cookie_utilization_percentage = cached_data&.dig(:cookie_utilization_percentage) || 0

        time_period = params[:filter_period].presence || "all"
        load_top_projects(time_period: time_period)
      rescue StandardError => e
        Rails.logger.error("[SuperMegaDashboard] Error in load_payouts_stats: #{e.class} - #{e.message}")
        @dollars_per_hour = 0
        @expenses_dollars_per_hour = 0
        @cookie_utilization_percentage = 0
      end

      def load_voting_stats
        cached_data = Rails.cache.fetch("super_mega_voting", expires_in: 10.minutes) do
          today = Time.current.beginning_of_day..Time.current.end_of_day
          this_week = 7.days.ago.beginning_of_day..Time.current

          avg_columns = Vote.enabled_categories.map do |category|
            column = Vote.score_column_for!(category)
            "AVG(#{column}) AS avg_#{category}"
          end.join(", ")

          select_core = <<~SQL.squish
            COUNT(*) AS total_votes,
            COUNT(*) FILTER (WHERE created_at >= ? AND created_at <= ?) AS votes_today,
            COUNT(*) FILTER (WHERE created_at >= ?) AS votes_this_week,
            AVG(time_taken_to_vote) AS avg_time,
            COUNT(*) FILTER (WHERE repo_url_clicked = true) AS repo_clicks,
            COUNT(*) FILTER (WHERE demo_url_clicked = true) AS demo_clicks,
            COUNT(*) FILTER (WHERE reason IS NOT NULL AND reason != '') AS with_reason
          SQL
          select_sql = Vote.sanitize_sql_array([
            avg_columns.present? ? "#{select_core}, #{avg_columns}" : select_core,
            today.begin, today.end, this_week.begin
          ])

          vote_stats = Vote.select(select_sql).take
          total = vote_stats.total_votes.to_i

          voting_overview = {
            total: total,
            today: vote_stats.votes_today.to_i,
            this_week: vote_stats.votes_this_week.to_i,
            avg_time_seconds: vote_stats.avg_time&.round,
            repo_click_rate: total > 0 ? (vote_stats.repo_clicks.to_f / total * 100).round(1) : 0,
            demo_click_rate: total > 0 ? (vote_stats.demo_clicks.to_f / total * 100).round(1) : 0,
            reason_rate: total > 0 ? (vote_stats.with_reason.to_f / total * 100).round(1) : 0
          }

          voting_category_avgs = Vote.enabled_categories.index_with do |category|
            vote_stats.send(:"avg_#{category}")&.to_f&.round(2)
          end

          windows = {
            "24h" => 1.day,
            "1w" => 7.days,
            "1m" => 30.days,
            "all" => 6.months
          }

          quality_by_window = windows.transform_values do |duration|
            relation = Vote.legitimate
            relation = relation.where(created_at: duration.ago..Time.current) if duration
            avg = relation.average(:reason_quality_score)
            avg&.to_f&.round(3)
          end

          trend_window_days = 180
          trend_start = (trend_window_days - 1).days.ago.beginning_of_day
          trend_end = Time.current.end_of_day
          daily_avgs = Vote.legitimate
                           .where(created_at: trend_start..trend_end)
                           .group(Arel.sql("DATE(created_at)"))
                           .average(:reason_quality_score)
          dates = (0..(trend_window_days - 1)).map { |d| (trend_start.to_date + d) }
          labels = dates.map { |date| date.strftime("%b %-d") }
          values = dates.map do |date|
            v = daily_avgs[date]
            v.nil? ? nil : v.to_f.round(3)
          end
          hourly_start = 23.hours.ago.beginning_of_hour
          hourly_end = Time.current.end_of_hour
          hourly_avgs = Vote.legitimate
                             .where(created_at: hourly_start..hourly_end)
                             .group(Arel.sql("DATE_TRUNC('hour', created_at)"))
                             .average(:reason_quality_score)

          hourly_hours = (0..23).map { |h| (hourly_start + h.hours) }
          hourly_labels = hourly_hours.map { |ts| ts.strftime("%H:00") }
          hourly_values = hourly_hours.map do |ts|
            v = hourly_avgs[ts.beginning_of_hour]
            v.nil? ? nil : v.to_f.round(3)
          end

          counts = User::VoteVerdict.group(:verdict).count
          verdict_counts = {
            blessed: counts["blessed"].to_i,
            cursed: counts["cursed"].to_i,
            neutral: counts["neutral"].to_i,
            total: counts.values_at("blessed", "cursed", "neutral").compact.sum
          }

          recent_cursed = []
          begin
            versions = PaperTrail::Version
                         .where(item_type: "User::VoteVerdict", event: "update")
                         .where(created_at: 30.days.ago..Time.current)
                         .order(created_at: :desc)
                         .limit(300)

            verdict_ids = versions.pluck(:item_id)
            verdict_records = User::VoteVerdict.where(id: verdict_ids).includes(:user).index_by(&:id)

            seen_user_ids = Set.new
            versions.each do |v|
              changes = parse_version_object_changes(v.object_changes)
              verdict_change = changes["verdict"]
              next unless verdict_change.is_a?(Array) && verdict_change.size >= 2 && verdict_change[1] == "cursed"
              vr = verdict_records[v.item_id]
              next unless vr && vr.user
              user = vr.user
              next if seen_user_ids.include?(user.id)
              seen_user_ids << user.id

              cursed_at = v.created_at

              before_range = (cursed_at - 7.days)..(cursed_at - 1.second)
              after_range = cursed_at..(cursed_at + 7.days)

              before_avg = Vote.legitimate.where(user_id: user.id, created_at: before_range).average(:reason_quality_score)&.to_f&.round(3)
              after_avg = Vote.legitimate.where(user_id: user.id, created_at: after_range).average(:reason_quality_score)&.to_f&.round(3)

              before_count = Vote.legitimate.where(user_id: user.id, created_at: before_range).count
              after_count = Vote.legitimate.where(user_id: user.id, created_at: after_range).count

              recent_cursed << {
                user: user,
                cursed_at: cursed_at,
                before_avg: before_avg,
                before_count: before_count,
                after_avg: after_avg,
                after_count: after_count,
                analyze_path: Rails.application.routes.url_helpers.admin_vote_quality_dashboard_user_path(user.id, window_days: 30),
                votes_search_path: Rails.application.routes.url_helpers.admin_vote_quality_dashboard_user_path(user.id, window_days: 30)
              }
              break if recent_cursed.size >= 20
            end
          rescue StandardError => e
            Rails.logger.error("[SuperMegaDashboard] Error fetching recent cursed users: #{e.class} - #{e.message}")
            recent_cursed = []
          end

          {
            overview: voting_overview,
            category_avgs: voting_category_avgs,
            quality_by_window: quality_by_window,
            quality_trend: { labels: labels, values: values },
            quality_trend_hourly: { labels: hourly_labels, values: hourly_values },
            verdict_counts: verdict_counts,
            recent_cursed_users: recent_cursed
          }
        end

        @voting_overview = cached_data&.dig(:overview) || {}
        @voting_category_avgs = cached_data&.dig(:category_avgs) || {}
        @vote_quality_by_window = cached_data&.dig(:quality_by_window) || {}
        @vote_quality_trend = cached_data&.dig(:quality_trend) || { labels: [], values: [] }
        @vote_quality_trend_hourly = cached_data&.dig(:quality_trend_hourly) || { labels: [], values: [] }
        @vote_verdict_counts = cached_data&.dig(:verdict_counts) || { blessed: 0, cursed: 0, neutral: 0, total: 0 }
        @recent_cursed_users = cached_data&.dig(:recent_cursed_users) || []

        begin
          @current_cursed_users = User::VoteVerdict.includes(:user).where(verdict: "cursed").order(updated_at: :desc)
          @current_blessed_users = User::VoteVerdict.includes(:user).where(verdict: "blessed").order(updated_at: :desc)
        rescue StandardError => e
          Rails.logger.error("[SuperMegaDashboard] Error fetching current verdict users: #{e.class} - #{e.message}")
          @current_cursed_users = []
          @current_blessed_users = []
        end

        @verdict_user_drilldowns = { "cursed" => {}, "blessed" => {} }
        build_verdict_drilldowns!(@current_cursed_users, type: "cursed")
        build_verdict_drilldowns!(@current_blessed_users, type: "blessed")
      end

      def build_verdict_drilldowns!(verdict_rel, type:)
        verdict_rel.each do |vr|
          user = vr.user
          next unless user

          transition_time = nil
          begin
            versions = PaperTrail::Version
              .where(item_type: "User::VoteVerdict", event: "update", item_id: vr.id)
              .order(created_at: :desc)
              .limit(50)
            versions.each do |ver|
              changes = parse_version_object_changes(ver.object_changes)
              verdict_change = changes["verdict"]
              if verdict_change.is_a?(Array) && verdict_change.size >= 2 && verdict_change[1] == type
                transition_time = ver.created_at
                break
              end
            end
            transition_time ||= vr.assessed_at if vr.verdict == type
          rescue StandardError => e
            Rails.logger.warn("[SuperMegaDashboard] transition lookup failed for user ##{user.id}: #{e.message}")
          end

          next unless transition_time

          before_rel = Vote.legitimate.where(user_id: user.id).where("created_at < ?", transition_time)
          after_rel  = Vote.legitimate.where(user_id: user.id).where("created_at >= ?", transition_time)
          before_avgs = before_rel.group(Arel.sql("DATE(created_at)")).average(:reason_quality_score)
          after_avgs  = after_rel.group(Arel.sql("DATE(created_at)")).average(:reason_quality_score)
          before_dates = before_avgs.keys.compact.sort
          after_dates  = after_avgs.keys.compact.sort
          label_dates = (before_dates.first(2) + after_dates.first(2)).compact.uniq.sort
          labels = label_dates.map { |d| d.strftime("%b %-d") }
          series_values = label_dates.map { |d| (before_avgs[d] || after_avgs[d])&.to_f&.round(3) }
          votes_before = before_rel.order(created_at: :desc)
          votes_after  = after_rel.order(created_at: :desc)

          @verdict_user_drilldowns[type][user.id] = {
            event_iso: transition_time.to_date.to_s,
            event_ts_iso: transition_time.iso8601,
            before_end_iso: before_dates.last&.to_s,
            after_start_iso: after_dates.first&.to_s,
            label_isos: label_dates.map(&:to_s),
            labels: labels,
            values: series_values,
            votes_before: serialize_votes_for_modal(votes_before),
            votes_after: serialize_votes_for_modal(votes_after)
          }
        end
      end

      def parse_version_object_changes(raw)
        return {} if raw.nil?
        return raw if raw.is_a?(Hash)
        str = raw.to_s
        begin
          parsed = JSON.parse(str)
          parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError
          begin
            parsed = YAML.safe_load(str, permitted_classes: [ Symbol, Time, Date ], aliases: true)
            parsed.is_a?(Hash) ? parsed.transform_keys(&:to_s) : {}
          rescue StandardError
            {}
          end
        end
      end

      def serialize_votes_for_modal(votes)
        votes.map do |v|
          {
            at: v.created_at.in_time_zone.strftime("%b %-d %Y %H:%M"),
            at_iso: v.created_at.iso8601,
            reason: v.reason.to_s,
            rq_score: v.reason_quality_score&.round(3),
            originality: v.originality_score,
            technical: v.technical_score,
            usability: v.usability_score,
            storytelling: v.storytelling_score
          }
        end
      end

      def load_sidequest_stats
        cached_data = Rails.cache.fetch("super_mega_sidequests", expires_in: 1.hour) do
          shipped_entries = SidequestEntry.joins(project: :ship_events).distinct.includes(project: :ship_events)
          shipped_projects = Project.joins(:ship_events).distinct.includes(:ship_events)
          shipped_projects_count = shipped_projects.count
          submitted_project_ids = shipped_entries.select(:project_id).distinct.pluck(:project_id).each_with_object({}) do |project_id, hash|
            hash[project_id] = true
          end
          accepted_project_ids = shipped_entries.approved.select(:project_id).distinct.pluck(:project_id).each_with_object({}) do |project_id, hash|
            hash[project_id] = true
          end
          submitted_projects_count = shipped_entries.select(:project_id).distinct.count
          accepted_projects_count = shipped_entries.approved.select(:project_id).distinct.count
          state_counts = shipped_entries.group(:aasm_state).count
          trend_window_start = 29.days.ago.beginning_of_day
          trend_window_end = Time.current.end_of_day
          shipped_ship_events = Post::ShipEvent
            .joins(post: :project)
            .where(post_ship_events: { created_at: trend_window_start..trend_window_end })
            .includes(post: :project)

          pending = state_counts["pending"] || 0
          approved = state_counts["approved"] || 0
          rejected = state_counts["rejected"] || 0
          reviewed = approved + rejected

          # Build breakdown data for all time ranges and metrics
          breakdown_24h_projects = build_breakdown_projects(23.hours.ago, Time.current, submitted_project_ids)
          breakdown_7d_projects = build_breakdown_projects(6.days.ago, Time.current, submitted_project_ids)
          breakdown_30d_projects = build_breakdown_projects(29.days.ago, Time.current, submitted_project_ids)

          breakdown_24h_hours = build_breakdown_hours(23.hours.ago, Time.current, submitted_project_ids)
          breakdown_7d_hours = build_breakdown_hours(6.days.ago, Time.current, submitted_project_ids)
          breakdown_30d_hours = build_breakdown_hours(29.days.ago, Time.current, submitted_project_ids)

          {
            totals: {
              total: shipped_entries.count,
              pending: pending,
              approved: approved,
              rejected: rejected,
              reviewed: reviewed,
              approval_rate: reviewed.positive? ? ((approved.to_f / reviewed) * 100).round(1) : 0,
              submitted_today: shipped_entries.where(created_at: Time.current.beginning_of_day..).count,
              submitted_7d: shipped_entries.where(created_at: 7.days.ago..).count,
              oldest_pending_at: shipped_entries.pending.minimum(:created_at),
              shipped_projects_count: shipped_projects_count,
              shipped_projects_with_sidequest_submission_count: submitted_projects_count,
              shipped_projects_with_sidequest_submission_pct: shipped_projects_count.positive? ? ((submitted_projects_count.to_f / shipped_projects_count) * 100).round(1) : 0,
              accepted_projects_count: accepted_projects_count,
              accepted_projects_pct: submitted_projects_count.positive? ? ((accepted_projects_count.to_f / submitted_projects_count) * 100).round(1) : 0
            },
            breakdown_data: {
              "24h" => {
                projects: breakdown_24h_projects,
                hours: breakdown_24h_hours
              },
              "7d" => {
                projects: breakdown_7d_projects,
                hours: breakdown_7d_hours
              },
              "30d" => {
                projects: breakdown_30d_projects,
                hours: breakdown_30d_hours
              }
            },
            trend_data: build_sidequest_trend_data(shipped_ship_events.to_a, submitted_project_ids, accepted_project_ids)
          }
        end

        @sidequest_totals = cached_data&.dig(:totals) || {}
        @sidequest_breakdown_data = cached_data&.dig(:breakdown_data) || {}
        @sidequest_trend_data = cached_data&.dig(:trend_data) || {}
      rescue StandardError => e
        Rails.logger.error("[SuperMegaDashboard] Error in load_sidequest_stats: #{e.message}")
        @sidequest_totals = {}
        @sidequest_breakdown_data = {}
        @sidequest_trend_data = {}
      end

      def build_sidequest_trend_data(ship_events, submitted_project_ids, accepted_project_ids)
        {
          "24h" => build_sidequest_trend_window(
            ship_events: ship_events,
            submitted_project_ids: submitted_project_ids,
            accepted_project_ids: accepted_project_ids,
            start_time: 23.hours.ago.beginning_of_hour,
            step: 1.hour,
            bucket_count: 24,
            labeler: ->(time) { time.strftime("%-l %p") }
          ),
          "7d" => build_sidequest_trend_window(
            ship_events: ship_events,
            submitted_project_ids: submitted_project_ids,
            accepted_project_ids: accepted_project_ids,
            start_time: 6.days.ago.beginning_of_day,
            step: 1.day,
            bucket_count: 7,
            labeler: ->(time) { time.strftime("%a") }
          ),
          "30d" => build_sidequest_trend_window(
            ship_events: ship_events,
            submitted_project_ids: submitted_project_ids,
            accepted_project_ids: accepted_project_ids,
            start_time: 29.days.ago.beginning_of_day,
            step: 1.day,
            bucket_count: 30,
            labeler: ->(time) { time.strftime("%b %-d") }
          )
        }
      end

      def build_sidequest_trend_window(ship_events:, submitted_project_ids:, accepted_project_ids:, start_time:, step:, bucket_count:, labeler:)
        labels = bucket_count.times.map { |index| labeler.call(start_time + (step * index)) }

        trend_series = {
          projects: {
            total: Array.new(bucket_count, 0),
            submitted: Array.new(bucket_count, 0),
            accepted: Array.new(bucket_count, 0)
          },
          hours: {
            total: Array.new(bucket_count, 0.0),
            submitted: Array.new(bucket_count, 0.0),
            accepted: Array.new(bucket_count, 0.0)
          }
        }

        ship_events.each do |ship_event|
          project_id = ship_event.post&.project_id
          next unless project_id.present?

          shipped_index = trend_bucket_index(ship_event.created_at, start_time: start_time, step: step, bucket_count: bucket_count)
          next unless shipped_index

          hours_value = ship_event.hours.to_f
          trend_series[:projects][:total][shipped_index] += 1
          trend_series[:hours][:total][shipped_index] += hours_value

          if submitted_project_ids[project_id]
            trend_series[:projects][:submitted][shipped_index] += 1
            trend_series[:hours][:submitted][shipped_index] += hours_value
          end

          next unless accepted_project_ids[project_id]

          trend_series[:projects][:accepted][shipped_index] += 1
          trend_series[:hours][:accepted][shipped_index] += hours_value
        end

        trend_series[:hours].each_value do |series|
          series.map! { |value| value.round(1) }
        end

        {
          labels: labels,
          series: trend_series
        }
      end

      def trend_bucket_index(timestamp, start_time:, step:, bucket_count:)
        return nil unless timestamp.present?

        normalized_timestamp = timestamp.in_time_zone
        normalized_start_time = start_time.in_time_zone
        index = ((normalized_timestamp.to_i - normalized_start_time.to_i) / step.to_i).floor
        index if index.between?(0, bucket_count - 1)
      end

      def build_breakdown_hours(start_time, end_time, sidequest_project_ids)
        return {} if sidequest_project_ids.empty?

        project_ids = sidequest_project_ids.keys

        # Assign each project to one sidequest title (latest entry) to avoid
        # multiplying the same ship event across multiple sidequests.
        project_titles = {}
        SidequestEntry
          .joins(:sidequest)
          .where(project_id: project_ids)
          .order(created_at: :desc, id: :desc)
          .pluck(:project_id, "sidequests.title")
          .each do |project_id, title|
            project_titles[project_id] ||= title
          end

        totals = Hash.new(0.0)
        Post::ShipEvent
          .joins(:post)
          .where(post_ship_events: { created_at: start_time..end_time })
          .where(posts: { project_id: project_ids })
          .where.not(hours: nil)
          .pluck("posts.project_id", :hours)
          .each do |project_id, hours|
            title = project_titles[project_id]
            next if title.blank?

            value = hours.to_f
            next if value <= 0

            totals[title] += value
          end

        totals
          .sort_by { |_title, total_hours| -total_hours }
          .first(20)
          .to_h
          .transform_values { |value| value.round(1) }
      rescue StandardError => e
        Rails.logger.error("[SuperMegaDashboard] build_breakdown_hours error: #{e.message}")
        {}
      end

      def build_breakdown_projects(start_time, end_time, sidequest_project_ids)
        breakdown = {}

        Post::ShipEvent
          .joins(post: :project)
          .joins("INNER JOIN sidequest_entries ON sidequest_entries.project_id = projects.id")
          .joins("INNER JOIN sidequests ON sidequests.id = sidequest_entries.sidequest_id")
          .where(post_ship_events: { created_at: start_time..end_time })
          .where(projects: { id: sidequest_project_ids.keys })
          .group("sidequests.title")
          .select("sidequests.title, COUNT(DISTINCT projects.id) as total_projects")
          .order("total_projects DESC")
          .limit(20)
          .each do |row|
            breakdown[row.title] = row.total_projects.to_i
          end

        breakdown
      end

      def load_community_engagement_stats
        attendance_data = ShowAndTellAttendance.group(:date).count
        last_winner_attendance = ShowAndTellAttendance
                                   .where(winner: true)
                                   .order(date: :desc, updated_at: :desc)
                                   .includes(:project, :user)
                                   .first

        @show_and_tell_stats = {
          attendance_by_date: attendance_data,
          last_winner: last_winner_attendance
        }
      end

      def load_funnel_stats
        range_key = FunnelEvents::TimeRange.key(params[:range])
        window = FunnelEvents::TimeRange.window(range_key)

        cached_data = Rails.cache.fetch("super_mega_funnel_stats/#{range_key}", expires_in: 5.minutes) do
          begin
            funnel_steps = [
              "start_flow_started",
              "start_flow_name",
              "start_flow_project",
              "start_flow_devlog",
              "start_flow_signin",
              "identity_verified",
              "hackatime_linked",
              "project_created",
              "devlog_created"
            ]

            funnel_with_counts = FunnelEvents::StepCounter.count_distinct_by_group(
              relation: FunnelEvent,
              group_column: :event_name,
              distinct_column: :email,
              step_keys: funnel_steps,
              window: window
            )

            { funnel_steps: funnel_with_counts, range_key: range_key }
          rescue StandardError => e
            Rails.logger.error("[SuperMegaDashboard] Error in load_funnel_stats: #{e.message}")
            { funnel_steps: [], range_key: range_key }
          end
        end

        @funnel_steps = cached_data&.dig(:funnel_steps) || []
        @funnel_range_key = cached_data&.dig(:range_key) || "all"
      end

      def load_hcb_expenses
        data = Rails.cache.fetch("super_mega_hcb_stats", expires_in: 1.hour) do
          response = Faraday.get("https://hcb.hackclub.com/api/v3/organizations/flavortown")

          if response.success?
            body = JSON.parse(response.body)
            balance = body.dig("balances", "balance_cents") || 0
            total_raised = body.dig("balances", "total_raised") || 0

            {
              balance_cents: balance,
              total_raised_cents: total_raised,
              total_expenses_cents: total_raised - balance
            }
          end
        rescue StandardError => e
          { error: "Error fetching HCB stats: #{e.message}" }
        end

        @hcb_error = data[:error]
        @balance_cents = data[:balance_cents] || 0
        @total_expenses_cents = data[:total_expenses_cents] || 0
        @total_raised_cents = data[:total_raised_cents] || 0
        @hcb_spending_by_tag = fetch_hcb_spending_by_tag
      end

      def fetch_hcb_transactions
        Rails.cache.fetch("super_mega_hcb_transactions", expires_in: 1.hour) do
          transactions = []
          current_page = 1
          loop do
            response = Faraday.get("https://hcb.hackclub.com/api/v3/organizations/flavortown/transactions", { page: current_page, per_page: 50 })
            break unless response.success?
            data = JSON.parse(response.body)
            break if data.empty?
            transactions.concat(data)
            current_page += 1
          end
          transactions
        rescue StandardError => e
          Rails.logger.error("[SuperMegaDashboard] Error fetching HCB transactions: #{e.class} - #{e.message}")
          []
        end
      end

      def fetch_hcb_spending_by_tag
        transactions = fetch_hcb_transactions
        spending_by_tag = {}
        transactions.each do |txn|
          amount = txn["amount_cents"].to_i
          next unless amount < 0
          tags = txn["tags"] || []
          tag_names = tags.map { |tag| tag["label"] }
          if tag_names.any?
            tag_names.each do |tag_name|
              spending_by_tag[tag_name] ||= 0
              spending_by_tag[tag_name] += amount.abs
            end
          else
            spending_by_tag["Untagged"] ||= 0
            spending_by_tag["Untagged"] += amount.abs
          end
        end
        spending_by_tag.transform_values { |amount| amount / 100.0 }
      end

      def load_flavortime_summary
        with_dashboard_timing("flavortime") do
          cached_data = Rails.cache.fetch("super_mega_flavortime_summary", expires_in: dashboard_cache_ttl(30.seconds, 2.minutes)) do
            scoped_sessions = FlavortimeSession.all

            {
              summary: {
                active_users: FlavortimeSession.active_users_count,
                total_users: FlavortimeSession.select(:user_id).distinct.count,
                total_sessions: FlavortimeSession.count,
                status_hours: (FlavortimeSession.sum(:discord_status_seconds).to_f / 3600).round(1),
                activity_chart: build_flavortime_activity_chart(scoped_sessions)
              }
            }
          end

          @flavortime_summary = empty_flavortime_summary.merge(cached_data.fetch(:summary, {}))
        end
      rescue StandardError => e
        Rails.logger.warn("[SuperMegaDashboard] Flavortime section unavailable (#{e.class}): #{e.message}")
        @flavortime_summary = empty_flavortime_summary.merge(error: "Flavortime data is temporarily unavailable")
      end

      def load_pyramid_scheme_stats
        payload = with_dashboard_timing("pyramid_scheme") do
          Rails.cache.fetch("super_mega_pyramid_scheme_stats_v2", expires_in: dashboard_cache_ttl(30.seconds, 5.minutes)) do
            PyramidReferralService.fetch_dashboard_stats
          end
        end

        if payload.blank? || payload["error"].present?
          @pyramid_scheme_stats = { error: payload&.dig("error") || "Pyramid dashboard stats are unavailable" }
          return
        end

        @pyramid_scheme_stats = {
          activity_timeline: payload.dig("activity", "timeline") || []
        }
      rescue StandardError => e
        Rails.logger.warn("[SuperMegaDashboard] Pyramid section unavailable (#{e.class}): #{e.message}")
        @pyramid_scheme_stats = { error: "Pyramid dashboard stats are temporarily unavailable" }
      end

      def fetch_approved_ysws_db_hours
        api_key = ENV["UNIFIED_DB_INTEGRATION_AIRTABLE_KEY"]

        table = Norairrecord.table(api_key, "app3A5kJwYqxMLOgh", "YSWS Programs")
        record = table.all(filter: "{Name} = 'Flavortown'").first

        weighted_total = record&.fields&.dig("Weighted–Total")

        weighted_total.to_f * 10
      rescue StandardError => e
        Rails.logger.error("[SuperMegaDashboard] Error fetching approved YSWS hours: #{e.class} - #{e.message}")
        0
      end

      def build_transaction_data
        transactions = fetch_hcb_transactions
        total_expenses = 0
        transactions.each do |txn|
          amount = txn["amount_cents"].to_i
          next unless amount < 0
          has_contributor_tag = txn["tags"]&.any? { |tag| tag["label"] == "Contributor" }
          unless has_contributor_tag
            total_expenses += amount.abs
          end
        end
        {
          total_expenses: total_expenses / 100
        }
      end

      def balance_color_class(balance_cents)
        balance_dollars = balance_cents.to_i / 100
        case balance_dollars
        when 0..1999
          "balance--red"
        when 2000..9999
          "balance--yellow"
        else
          "balance--green"
        end
      end

      def build_flavortime_activity_chart(scope)
        date_range = 13.days.ago.to_date..Time.current.to_date
        sessions_by_day = scope
          .where(created_at: date_range.first.beginning_of_day..date_range.last.end_of_day)
          .group(Arel.sql("DATE(created_at)"))
          .count
        status_hours_by_day = scope
          .where(created_at: date_range.first.beginning_of_day..date_range.last.end_of_day)
          .group(Arel.sql("DATE(created_at)"))
          .sum(:discord_status_seconds)

        {
          labels: date_range.map { |date| date.strftime("%b %-d") },
          sessions: date_range.map { |date| sessions_by_day[date] || 0 },
          status_hours: date_range.map { |date| ((status_hours_by_day[date] || 0).to_f / 3600).round(1) }
        }
      end

      def empty_flavortime_summary
        {
          active_users: 0,
          total_users: 0,
          total_sessions: 0,
          status_hours: 0,
          activity_chart: {
            labels: [],
            sessions: [],
            status_hours: []
          }
        }
      end

      def compact_flavortime_breakdown(counts, limit: 5)
        return {} if counts.blank?

        top_counts = counts.to_a.first(limit)
        remaining_count = counts.to_a.drop(limit).sum { |(_, count)| count }

        chart_data = top_counts.to_h
        chart_data["other"] = remaining_count if remaining_count.positive?
        chart_data
      end

      def chg(old, new)
        return nil if old.nil? || new.nil? || old.zero?

        ((new - old) / old.to_f * 100).round
      end

      def dashboard_cache_ttl(development_ttl, production_ttl)
        Rails.env.development? ? development_ttl : production_ttl
      end

      def with_dashboard_timing(section_name)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
        Rails.logger.info("[SuperMegaDashboard] #{section_name} loaded in #{elapsed_ms}ms")
        result
      end

      def load_top_projects(time_period: "24h")
        cached_data = Rails.cache.fetch("super_mega_top_projects_#{time_period}", expires_in: 5.minutes) do
          time_range = calculate_time_range(time_period)

          payout_entries = LedgerEntry
            .where(ledgerable_type: "Post::ShipEvent", created_by: "ship_event_payout")
            .select("ledgerable_id, MAX(created_at) AS payout_at")
            .group("ledgerable_id")

          ship_events = Post::ShipEvent
            .joins(post: :project)
            .where.not(payout: nil)
            .joins("INNER JOIN (#{payout_entries.to_sql}) payout_entries ON payout_entries.ledgerable_id = post_ship_events.id")
            .where("payout_entries.payout_at >= ? AND payout_entries.payout_at <= ?", time_range.begin, time_range.end)
            .includes(post: { project: { banner_attachment: :blob, memberships: :user } })
            .select("post_ship_events.*, projects.title, projects.id as project_id, payout_entries.payout_at AS payout_at")

          projects_data = ship_events.group_by { |event| event.post.project_id }.map do |project_id, events|
            next nil if events.blank?

            project = events.first.post.project
            project_title = project.title
            ship_event_payout = events.map(&:payout).compact.max.to_f
            max_multiplier = events.map(&:multiplier).compact.max || 0
            creator = project.users.first

            {
              project_id: project_id,
              project: project,
              title: project_title,
              ship_event_payout: ship_event_payout.round,
              max_multiplier: max_multiplier.round(2),
              creator: creator
            }
          end.compact

          highest_multiplier_projects = projects_data
            .sort_by { |p| [ -p[:max_multiplier].to_f, -p[:ship_event_payout].to_f ] }
            .first(10)

          largest_payout_projects = projects_data
            .sort_by { |p| [ -p[:ship_event_payout].to_f, -p[:max_multiplier].to_f ] }
            .first(10)

          {
            highest_multiplier: highest_multiplier_projects.first,
            largest_payout: largest_payout_projects.first,
            highest_multiplier_projects: highest_multiplier_projects,
            largest_payout_projects: largest_payout_projects,
            all_projects: projects_data
          }
        end

        @top_projects_data = cached_data || {}
        @highest_multiplier_project = @top_projects_data[:highest_multiplier] || {}
        @largest_payout_project = @top_projects_data[:largest_payout] || {}
        @highest_multiplier_projects = @top_projects_data[:highest_multiplier_projects] || []
        @largest_payout_projects = @top_projects_data[:largest_payout_projects] || []
      rescue StandardError => e
        Rails.logger.error("[SuperMegaDashboard] Error in load_top_projects: #{e.class} - #{e.message}")
        @top_projects_data = {}
        @highest_multiplier_project = {}
        @largest_payout_project = {}
        @highest_multiplier_projects = []
        @largest_payout_projects = []
      end

      def calculate_time_range(time_period)
        now = Time.current
        case time_period
        when "24h"
          24.hours.ago..now
        when "week"
          7.days.ago..now
        when "month"
          30.days.ago..now
        when "all"
          Time.zone.at(0)..now
        else
          24.hours.ago..now
        end
      end
    end
  end
end
