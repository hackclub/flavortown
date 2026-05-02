class WrappedPresenter
  # How many recent days to show in the activity-pulse heatmap on the bento.
  ACTIVITY_PULSE_DAYS = 70

  def initialize(user)
    @user = user
  end

  def user
    @user
  end

  SUPPORT_API       = "https://flavortown.nephthys.hackclub.com/api/user"
  SHIPWRIGHT_API    = "https://review.hackclub.com/api/admin/ship-certs-log"
  SHIPWRIGHT_TOKEN  = ENV.fetch("SW_ADMIN_KEY", nil)

  SHIPWRIGHT_REVIEWER_IDS = {
    "U091PP9SN02" => 1,  "U092F9A8VMY" => 2,  "U093H5LJHGC" => 3,
    "U08B60DCYG2" => 4,  "U07A0D5K3T2" => 5,  "U090JSHV8QJ" => 6,
    "U07H3E1CW7J" => 7,  "U091HBJLQS2" => 8,  "U091R9Y6HFE" => 9,
    "U08SKE8JU5S" => 10, "U080V8UG5BR" => 11, "U081C6XT885" => 12,
    "U08RWM5U4L9" => 13, "U096KJYT1PU" => 14, "U07LK6JJ9DE" => 15,
    "U079EQY9X1D" => 16, "U091HG1TP6K" => 17, "U07EB2Y76DP" => 18,
    "U092CSW4FGQ" => 19, "U091DE0M4NB" => 20, "U096UJ1L3L2" => 21,
    "U07FHT3BNTT" => 22,  "U09UQ385LSG" => 24,
    "U0829HRSQ76" => 25, "U082GTRTR5X" => 26, "U054VC2KM9P" => 27,
    "U0823F39GV8" => 28, "U07ES48RES3" => 29, "U091G6M9AB0" => 30,
    "U09UE480JHH" => 31, "U072PTA5BNG" => 32, "U0826R42R98" => 33,
    "U05F4B48GBF" => 34, "UDK5M9Y13"   => 35, "U07960MD940" => 36,
    "U078VEX14CB" => 37, "U094P415ZE3" => 38, "U080A3QP42C" => 40,
    "U0828FYS2UC" => 41, "U091KE59H5H" => 42, "U08GCDHM0QZ" => 43,
    "U07LKN2HXT3" => 44, "U07UK4S94KC" => 45, "U08NXJL86KT" => 46,
    "U090LAT6QKB" => 47, "U084UQFF0LC" => 48, "U091M21518T" => 49,
    "U07950S3GMC" => 50, "U0C7B14Q3"   => 51, "U020X4GCWSF" => 52,
    "U08R49H9VRV" => 53, "U09PHG7RLGG" => 54, "U078VEJRBR7" => 55,
    "U078DFX40A2" => 56, "U07AGEVSTD2" => 57, "U0A1NME3EJD" => 58,
    "U08AT086H8E" => 59, "U07UBCSSQH3" => 60, "U078WRWQPGF" => 61,
    "U0A6A0J7UE6" => 62, "U081ZC7ES30" => 63, "U07E8H9A24A" => 64,
    "U07BN55GN3D" => 65, "U0A4UTULSLE" => 66, "U09H4M0523Z" => 67,
    "U096RMRG03G" => 68, "U09192704Q7" => 69
  }.freeze

  # ─── Role helpers (drive optional slide content) ────────────────
  def fraud_dept?
    @user.has_role?(:fraud_dept) || @user.admin?
  end

  def fulfillment_team?
    @user.has_role?(:fulfillment_person) || @user.admin?
  end

  def support_helper?
    support_stats[:helper] == true
  end

  def shipwright_reviewer?
    SHIPWRIGHT_TOKEN.present? && SHIPWRIGHT_REVIEWER_IDS.key?(@user.slack_id) && shipwright_stats.present?
  end

  def shipwright_stats
    @shipwright_stats ||= Rails.cache.fetch("wrapped_shipwright_#{@user.slack_id}", expires_in: 15.minutes) do
      reviewer_id = SHIPWRIGHT_REVIEWER_IDS[@user.slack_id]
      next nil unless reviewer_id

      response = shipwright_connection.get("/api/admin/ship-certs-log") { |r| r.params["reviewerId"] = reviewer_id }
      next nil unless response.success?

      certs = JSON.parse(response.body, symbolize_names: true)
      next nil unless certs.is_a?(Array) && certs.any?

      {
        total:    certs.length,
        approved: certs.count { |c| c[:status] == "approved" },
        rejected: certs.count { |c| c[:status] == "rejected" },
        pending:  certs.count { |c| c[:status] == "pending" }
      }
    rescue StandardError
      nil
    end
  end

  def support_stats
    @support_stats ||= Rails.cache.fetch("wrapped_support_#{@user.slack_id}", expires_in: 15.minutes) do
      response = Faraday.get(SUPPORT_API, { id: @user.slack_id })
      JSON.parse(response.body, symbolize_names: true)
    rescue StandardError
      {}
    end
  end

  def total_cookies_earned
    @total_cookies_earned ||= positive_entries.sum(:amount)
  end

  def cookies_spent
    @cookies_spent ||= negative_entries.sum(:amount).abs
  end

  def projects_count
    @projects_count ||= @user.projects.count
  end

  def best_ship_event
    @best_ship_event ||= Post::ShipEvent
      .joins(post: { project: :memberships })
      .where(memberships: { user_id: @user.id })
      .order(Arel.sql("post_ship_events.overall_score DESC NULLS LAST, post_ship_events.votes_count DESC"))
      .includes(post: :project)
      .first
  end

  def ships_count
    @ships_count ||= @user.projects.where.not(ship_status: "draft").count
  end

  def vote_verdict
    @vote_verdict ||= @user.vote_verdict&.verdict || "neutral"
  end

  def avg_vote_score
    @avg_vote_score ||= begin
      scores = @user.votes.where.not(originality_score: nil).pluck(
        :originality_score, :technical_score, :usability_score, :storytelling_score
      ).flatten.compact
      scores.any? ? (scores.sum.to_f / scores.size).round(1) : nil
    end
  end

  def avg_vote_words
    @avg_vote_words ||= begin
      reasons = @user.votes.where.not(reason: [ nil, "" ]).pluck(:reason)
      return nil if reasons.empty?
      (reasons.sum { |r| r.split.size }.to_f / reasons.size).round(1)
    end
  end

  def votes_cast
    @votes_cast ||= @user.votes.count
  end

  def devlogs_count
    @devlogs_count ||= Post.where(user_id: @user.id, postable_type: "Post::Devlog").count
  end

  def coding_seconds
    @coding_seconds ||= Post.where(user_id: @user.id, postable_type: "Post::Devlog")
    .joins("JOIN post_devlogs ON post_devlogs.id = posts.postable_id")
    .where(post_devlogs: { deleted_at: nil })
    .sum("post_devlogs.duration_seconds")
  end

  def coding_hours
    (coding_seconds / 3600.0).round(1)
  end

  # "276h 45m" — human friendly hours+minutes from coding_seconds.
  def coding_hours_minutes_label
    total_minutes = (coding_seconds / 60).to_i
    hours = total_minutes / 60
    minutes = total_minutes % 60
    "#{hours}h #{minutes}m built"
  end

  def shop_orders_count
    @shop_orders_count ||= @user.shop_orders.real.count
  end

  def shop_orders_list
    @shop_orders_list ||= @user.shop_orders.real
                              .includes(shop_item: { image_attachment: :blob })
                              .order(frozen_item_price: :desc)
  end

  # Returns 0-100 percentile (what % of opt-in users the current user outranks)
  # Returns nil if user has not opted in to the leaderboard
  def leaderboard_percentile
    return nil unless @user.leaderboard_optin?

    Rails.cache.fetch("wrapped_percentile_#{@user.id}", expires_in: 15.minutes) do
      my_balance = @user.ledger_entries.sum(:amount)
      total = User.where(leaderboard_optin: true, banned: false).count
      next nil if total == 0

      below_count = User.where(leaderboard_optin: true, banned: false)
                        .left_joins(:ledger_entries)
                        .group("users.id")
                        .having("COALESCE(SUM(ledger_entries.amount), 0) < ?", my_balance)
                        .count.length

      ((below_count.to_f / total) * 100).round
    end
  end

  # ─── Slide-specific aggregates ───────────────────────────────────

  def reports_filed
    @reports_filed ||= @user.reports.count
  end

  # Org-wide reports the fraud team has handled this season. Surfaced
  # only to fraud_dept users on the reports slide.
  def reports_team_handled
    @reports_team_handled ||= Project::Report.where.not(status: :pending).count
  end

  # Reports this user personally moved to reviewed or dismissed.
  def reports_personally_handled
    @reports_personally_handled ||= reports_personally_reviewed + reports_personally_dismissed
  end

  def reports_personally_reviewed
    @reports_personally_reviewed ||= PaperTrail::Version
      .where(item_type: "Project::Report")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'status'->>1 = '1'")
      .distinct
      .count(:item_id)
  end

  def reports_personally_dismissed
    @reports_personally_dismissed ||= PaperTrail::Version
      .where(item_type: "Project::Report")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'status'->>1 = '2'")
      .distinct
      .count(:item_id)
  end

  # Rank of this user on the reports leaderboard (most handled = rank 1).
  def reports_rank
    @reports_rank ||= begin
      counts = PaperTrail::Version
        .where(item_type: "Project::Report")
        .where("object_changes->'status'->>1 IN ('1', '2')")
        .group(:whodunnit)
        .distinct
        .count(:item_id)
      sorted = counts.sort_by { |_, v| -v }.map(&:first)
      pos = sorted.index(@user.id.to_s)
      pos ? pos + 1 : nil
    end
  end

  # Org-wide shop orders the fulfilment team has shipped out this season.
  # Surfaced to fulfillment_person + fraud_dept (admins).
  def orders_team_fulfilled
    @orders_team_fulfilled ||= ShopOrder.where.not(fulfilled_at: nil).count
  end

  def orders_personally_approved
    @orders_personally_approved ||= PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'aasm_state'->>1 = 'awaiting_periodical_fulfillment'")
      .distinct.count(:item_id)
  end

  def orders_personally_rejected
    @orders_personally_rejected ||= PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'aasm_state'->>1 = 'rejected'")
      .distinct.count(:item_id)
  end

  def orders_personally_held
    @orders_personally_held ||= PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'aasm_state'->>1 = 'on_hold'")
      .distinct.count(:item_id)
  end

  def orders_personally_fulfilled
    @orders_personally_fulfilled ||= PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where(whodunnit: @user.id.to_s)
      .where("object_changes->'aasm_state'->>1 = 'fulfilled'")
      .distinct.count(:item_id)
  end

  def orders_rank_fraud
    @orders_rank_fraud ||= begin
      counts = PaperTrail::Version
        .where(item_type: "ShopOrder")
        .where("object_changes->'aasm_state'->>1 IN ('awaiting_periodical_fulfillment', 'rejected', 'on_hold')")
        .group(:whodunnit).distinct.count(:item_id)
      sorted = counts.sort_by { |_, v| -v }.map(&:first)
      pos = sorted.index(@user.id.to_s)
      pos ? pos + 1 : nil
    end
  end

  def orders_rank_fulfillment
    @orders_rank_fulfillment ||= begin
      counts = PaperTrail::Version
        .where(item_type: "ShopOrder")
        .where("object_changes->'aasm_state'->>1 = 'fulfilled'")
        .group(:whodunnit).distinct.count(:item_id)
      sorted = counts.sort_by { |_, v| -v }.map(&:first)
      pos = sorted.index(@user.id.to_s)
      pos ? pos + 1 : nil
    end
  end

  def achievements_count
    @achievements_count ||= @user.achievements.count
  end

  def latest_achievement_slug
    @latest_achievement_slug ||= @user.achievements.order(earned_at: :desc).limit(1).pluck(:achievement_slug).first
  end

  def achievements_list
    @achievements_list ||= @user.achievements.order(earned_at: :desc).map do |ua|
      definition = Achievement.all.find { |a| a.slug.to_s == ua.achievement_slug.to_s }
      { name: definition&.name || ua.achievement_slug.to_s.humanize, icon: definition&.icon, earned_at: ua.earned_at&.strftime("%b %-d") }
    end
  end

  def achievements_by_visibility
    @achievements_by_visibility ||= begin
      slugs = @user.achievements.pluck(:achievement_slug).map(&:to_s)
      definitions = Achievement.all.select { |a| slugs.include?(a.slug.to_s) }
      {
        public: definitions.count { |a| a.visibility == :visible },
        secret: definitions.count { |a| a.visibility == :secret },
        hidden: definitions.count { |a| a.visibility == :hidden }
      }
    end
  end

  # SidequestEntry is project-scoped; pull approved entries through the
  # user's project memberships so each user sees only their own quests.
  def sidequests_completed
    @sidequests_completed ||= sidequests_list.length
  end

  def sidequests_list
    @sidequests_list ||= SidequestEntry.where(aasm_state: "approved")
                                       .joins(project: :memberships)
                                       .joins(:sidequest)
                                       .where(memberships: { user_id: @user.id })
                                       .distinct
                                       .includes(:sidequest)
                                       .map do |entry|
                                         sq = entry.sidequest
                                         { title: sq.title, icon_path: find_sidequest_icon(sq.slug) }
                                       end
  end

  # ─────────────────────────────────────────────────────────────────
  # Bento export data — JSON-serialisable summary of the highlights
  # cards. Kept here so the Stimulus controller stays presentational.
  # ─────────────────────────────────────────────────────────────────
  def bento_payload
    {
      total_cookies: total_cookies_earned,
      cookies_spent: cookies_spent,
      hours_label: coding_hours_minutes_label,
      devlogs: devlogs_count,
      ships: ships_count,
      orders: shop_orders_count,
      projects_touched: projects_count,
      active_days: active_days_count,
      tracked_hours: coding_hours,
      top_source: top_source_breakdown,
      activity_pulse: activity_pulse_buckets,
      biggest_gain: biggest_ledger_event(positive: true),
      biggest_spend: biggest_ledger_event(positive: false),
      peak_workday: peak_workday,
      strongest_weekday: strongest_weekday,
      role_badges: role_badges,
      is_admin: @user.admin?
    }
  end

  def role_badges
    badges = []
    badges << "🚀" if @user.has_role?(:project_certifier)
    badges << "👋" if @user.has_role?(:helper)
    badges << "👁"  if @user.has_role?(:fraud_dept)
    badges << "🎁" if @user.has_role?(:fulfillment_person)
    badges
  end

  def payout_breakdown
    @payout_breakdown ||= begin
      totals = Hash.new(0)
      positive_entries.each do |entry|
        reason = entry.reason.to_s
        key = if reason.include?("Show and Tell")
                "Show & Tell"
        elsif reason == "fraud payout uwu" || reason.include?("Fraud dept payout for first 2 months")
                "Fraud Dept"
        elsif reason.include?("Ship Reviews payout")
                "Shipwright"
        elsif reason.include?("GOI payout")
                "GOI"
        elsif reason.start_with?("Ship event payout:") || reason.start_with?("Bridge payout:")
                "Ship Events"
        else
                "Bonus"
        end
        totals[key] += entry.amount
      end
      totals.reject { |_, v| v.zero? }
             .sort_by { |_, v| -v }
             .to_h
    end
  end

  private

  def shipwright_connection
    Faraday.new("https://review.hackclub.com") do |f|
      f.headers["Authorization"] = "Bearer #{SHIPWRIGHT_TOKEN}"
    end
  end

  def find_sidequest_icon(slug)
    [ slug.to_s, slug.to_s.tr("_", "-") ].each do |name|
      %w[png svg avif jpg].each do |ext|
        return "sidequests/#{name}.#{ext}" if Rails.root.join("app/assets/images/sidequests/#{name}.#{ext}").exist?
      end
    end
    nil
  end

  def positive_entries
    @user.ledger_entries.where("amount > 0")
  end

  def negative_entries
    @user.ledger_entries.where("amount < 0")
  end

  # Top earning category by `created_by`, plus the share it represents.
  def top_source_breakdown
    totals = positive_entries.group(:created_by).sum(:amount)
    return nil if totals.empty?

    label, amount = totals.max_by { |_, value| value }
    total = totals.values.sum
    {
      label: humanize_ledger_source(label),
      percent: total.zero? ? 0 : ((amount.to_f / total) * 100).round,
      breakdown: totals.sort_by { |_, value| -value }.first(6).map { |key, value|
        { label: humanize_ledger_source(key), amount: value }
      }
    }
  end

  def humanize_ledger_source(raw)
    return "Unknown" if raw.blank?
    raw.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  # Devlog/coding activity binned per day for the last ACTIVITY_PULSE_DAYS.
  def activity_pulse_buckets
    cutoff = ACTIVITY_PULSE_DAYS.days.ago.to_date
    devlog_counts = Post.where(user_id: @user.id, postable_type: "Post::Devlog")
                        .where("created_at >= ?", cutoff)
                        .group("DATE(created_at)").count

    coding_counts = @user.flavortime_sessions
                         .where("created_at >= ?", cutoff)
                         .group("DATE(created_at)").sum(:discord_shared_seconds)

    (0...ACTIVITY_PULSE_DAYS).map do |offset|
      day = cutoff + offset
      devlogs = devlog_counts[day] || 0
      hours = (coding_counts[day] || 0) / 3600.0
      # Combined intensity score — a devlog counts roughly as one hour.
      devlogs + hours
    end
  end

  def active_days_count
    activity_pulse_buckets.count(&:positive?)
  end

  def biggest_ledger_event(positive:)
    scope = positive ? positive_entries : negative_entries
    entry = positive ? scope.order(amount: :desc).first : scope.order(amount: :asc).first
    return nil unless entry

    { amount: entry.amount.abs, date: entry.created_at.strftime("%b %-d") }
  end

  # Day where the user logged the most coding hours, plus the hours total.
  def peak_workday
    totals = @user.flavortime_sessions.group("DATE(created_at)").sum(:discord_shared_seconds)
    return nil if totals.empty?

    day, seconds = totals.max_by { |_, value| value }
    { date: day.to_date.strftime("%b %-d"), hours: (seconds / 3600.0).round(1) }
  end

  # Weekday on which the user logs the most coding time overall.
  def strongest_weekday
    totals = @user.flavortime_sessions.group("DATE(created_at)").sum(:discord_shared_seconds)
    return nil if totals.empty?

    by_weekday = totals.each_with_object(Hash.new(0)) do |(day, seconds), acc|
      acc[day.to_date.wday] += seconds
    end
    weekday_index, seconds = by_weekday.max_by { |_, value| value }
    {
      label: Date::ABBR_DAYNAMES[weekday_index],
      hours: (seconds / 3600.0).round(1)
    }
  end
end
