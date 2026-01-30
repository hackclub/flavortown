class FraudDailySummaryJob < ApplicationJob
  queue_as :default

  FRAUD_CHANNEL_ID = "C09M3TTQVC5"

  include Rails.application.routes.url_helpers

  def perform
    return unless Flipper.enabled?(:fraud_daily_summary)

    stats = gather_stats
    message = build_message(stats)

    SendSlackDmJob.perform_later(FRAUD_CHANNEL_ID, message)
  end

  private

  def gather_stats
    today = Time.current.beginning_of_day..Time.current.end_of_day

    {
      shop_orders: gather_shop_order_stats(today),
      reports: gather_report_stats(today),
      all_time: gather_all_time_stats
    }
  end

  def gather_shop_order_stats(today)
    order_versions_today = PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where(created_at: today)
      .where.not(whodunnit: nil)
      .where("object_changes ? 'aasm_state'")

    top_reviewers = calculate_top_reviewers(order_versions_today, "aasm_state", %w[awaiting_periodical_fulfillment rejected on_hold fulfilled])

    new_orders_today = ShopOrder.where(created_at: today).count
    pending_orders = ShopOrder.where(aasm_state: "pending").count
    awaiting_fulfillment = ShopOrder.where(aasm_state: "awaiting_periodical_fulfillment").count

    avg_response_time = calculate_avg_response_time_orders

    {
      top_reviewers: top_reviewers,
      new_today: new_orders_today,
      pending: pending_orders,
      awaiting_fulfillment: awaiting_fulfillment,
      backlog: pending_orders + awaiting_fulfillment,
      avg_response_hours: avg_response_time
    }
  end

  def gather_report_stats(today)
    report_versions_today = PaperTrail::Version
      .where(item_type: "Project::Report")
      .where(created_at: today)
      .where.not(whodunnit: nil)
      .where("object_changes ? 'status'")

    top_reviewers = calculate_top_reviewers(report_versions_today, "status", %w[reviewed dismissed])

    new_reports_today = Project::Report.where(created_at: today).count
    pending_reports = Project::Report.pending.count

    avg_response_time = calculate_avg_response_time_reports

    {
      top_reviewers: top_reviewers,
      new_today: new_reports_today,
      pending: pending_reports,
      avg_response_hours: avg_response_time
    }
  end

  def gather_all_time_stats
    order_versions = PaperTrail::Version
      .where(item_type: "ShopOrder")
      .where.not(whodunnit: nil)
      .where("object_changes ? 'aasm_state'")

    report_versions = PaperTrail::Version
      .where(item_type: "Project::Report")
      .where.not(whodunnit: nil)
      .where("object_changes ? 'status'")

    order_top = calculate_top_reviewers(order_versions, "aasm_state", %w[awaiting_periodical_fulfillment rejected on_hold fulfilled])
    report_top = calculate_top_reviewers(report_versions, "status", %w[reviewed dismissed])

    {
      orders: order_top,
      reports: report_top
    }
  end

  def calculate_top_reviewers(versions, change_field, valid_states)
    action_counts = versions.each_with_object(Hash.new(0)) do |version, counts|
      user_id = version.whodunnit.to_i
      next if user_id.zero?

      changes = version.object_changes || {}
      next if changes.is_a?(String) && changes.start_with?("---")
      changes = JSON.parse(changes) if changes.is_a?(String)
      state_change = changes[change_field]
      next unless state_change.is_a?(Array) && state_change.length == 2
      next unless valid_states.include?(state_change[1])

      counts[user_id] += 1
    end

    top_users = action_counts.sort_by { |_, v| -v }.first(3)
    user_ids = top_users.map(&:first)
    users_by_id = User.where(id: user_ids).index_by(&:id)

    top_users.map do |(user_id, count)|
      user = users_by_id[user_id]
      { name: user&.display_name || "User ##{user_id}", count: count }
    end
  end

  def calculate_avg_response_time_orders
    recent_orders = ShopOrder
      .where(aasm_state: %w[awaiting_periodical_fulfillment rejected fulfilled])
      .where("created_at > ?", 30.days.ago)
      .limit(100)

    return nil if recent_orders.empty?

    total_hours = recent_orders.sum do |order|
      first_action = order.versions.find do |v|
        changes = v.object_changes
        next if changes.is_a?(String) && changes.start_with?("---")
        changes = JSON.parse(changes) if changes.is_a?(String)
        changes&.dig("aasm_state")&.last.in?(%w[awaiting_periodical_fulfillment rejected])
      end
      next 0 unless first_action

      (first_action.created_at - order.created_at) / 1.hour
    end

    (total_hours / recent_orders.count).round(1)
  end

  def calculate_avg_response_time_reports
    recent_reports = Project::Report
      .where(status: %w[reviewed dismissed])
      .where("created_at > ?", 30.days.ago)
      .limit(100)

    return nil if recent_reports.empty?

    total_hours = recent_reports.sum do |report|
      first_action = PaperTrail::Version
        .where(item_type: "Project::Report", item_id: report.id)
        .where("object_changes ? 'status'")
        .order(:created_at)
        .first

      next 0 unless first_action

      (first_action.created_at - report.created_at) / 1.hour
    end

    (total_hours / recent_reports.count).round(1)
  end

  def build_message(stats)
    orders = stats[:shop_orders]
    reports = stats[:reports]

    msg = <<~MSG
      *🌅 Daily Fraud Summary*

      *📦 Shop Orders*
      #{format_top_3("Today's MVPs", orders[:top_reviewers])}
      • New orders today: *#{orders[:new_today]}*
      • Pending review: *#{orders[:pending]}*
      • Awaiting fulfillment: *#{orders[:awaiting_fulfillment]}*
      • Total backlog: *#{orders[:backlog]}* orders
      #{orders[:avg_response_hours] ? "• Avg response time (30d): *#{orders[:avg_response_hours]}h*" : ""}

      *🚨 Reports*
      #{format_top_3("Today's MVPs", reports[:top_reviewers])}
      • New reports today: *#{reports[:new_today]}*
      • Pending review: *#{reports[:pending]}*
      #{reports[:avg_response_hours] ? "• Avg response time (30d): *#{reports[:avg_response_hours]}h*" : ""}

      #{catchup_message(orders[:backlog], reports[:pending])}

      *🏆 All-Time Leaderboard*
      #{format_top_3("Shop Orders", stats[:all_time][:orders])}
      #{format_top_3("Reports", stats[:all_time][:reports])}
    MSG

    msg.strip
  end

  def format_top_3(title, reviewers)
    return "#{title}: _No activity yet today_" if reviewers.empty?

    medals = [ "🥇", "🥈", "🥉" ]
    lines = reviewers.each_with_index.map do |r, i|
      "#{medals[i]} #{r[:name]} (#{r[:count]})"
    end

    "#{title}: #{lines.join(" | ")}"
  end

  def catchup_message(order_backlog, report_backlog)
    total = order_backlog + report_backlog

    if total == 0
      "🎉 *Inbox zero achieved!* Take a well-deserved break!"
    elsif total < 10
      "📊 Almost there! Only *#{total}* items to review."
    elsif total < 50
      "📊 *#{total}* items in the queue. We've got this!"
    else
      "📊 *#{total}* items waiting. Let's chip away at it together! 💪"
    end
  end
end
