# frozen_string_literal: true

module Admin
  class FunnelEventsController < Admin::ApplicationController
    def index
      authorize :admin, :access_super_mega_dashboard?

      @range_key = FunnelEvents::TimeRange.key(params[:range])
      @window = FunnelEvents::TimeRange.window(@range_key)

      @funnels = funnels_for_window(window: @window)
    end

    private

    def starter_steps(window: nil)
      count_funnel_event_steps([ "start_flow_started", "identity_verified" ], window: window)
    end

    def funnels_for_window(window: nil)
      [
        p2p_funnel(window: window),
        sidequest_funnel(window: window),
        voting_curse_funnel(window: window),
        voting_blessing_funnel(window: window),
        ship_certification_to_payout_funnel(window: window),
        devlog_ship_show_and_tell_funnel(window: window)
      ]
    end

    def p2p_funnel(window: nil)
      {
        key: "project",
        title: "P2P",
        subtitle: "(start) project to prize",
        steps: starter_steps(window: window) + p2p_funnel_steps(window: window)
      }
    end

    def sidequest_funnel(window: nil)
      {
        key: "sidequests",
        title: "Sidequest Flow",
        subtitle: "Sidequest Funnel",
        steps: starter_steps(window: window) + sidequest_funnel_steps(window: window)
      }
    end

    def voting_curse_funnel(window: nil)
      {
        key: "voting_curse",
        title: "Voting (Curse)",
        subtitle: "Casting votes, casting more events, getting cursed and removing a curse",
        steps: starter_steps(window: window) + voting_funnel_steps(
          window: window,
          extra_steps: [
            verdict_transition_step(name: "got_cursed", from_values: %w[neutral blessed], to_value: "cursed", window: window),
            verdict_transition_step(name: "curse_removed", from_values: [ "cursed" ], to_value: "neutral", window: window)
          ]
        )
      }
    end

    def voting_blessing_funnel(window: nil)
      {
        key: "voting_blessing",
        title: "Voting (Blessing)",
        subtitle: "Casting votes, casting more votes, getting blessed, and removing a blessing",
        steps: starter_steps(window: window) + voting_funnel_steps(
          window: window,
          extra_steps: [
            verdict_transition_step(name: "got_blessed", from_values: %w[neutral cursed], to_value: "blessed", window: window),
            verdict_transition_step(name: "blessing_removed", from_values: [ "blessed" ], to_value: "neutral", window: window)
          ]
        )
      }
    end

    def ship_certification_to_payout_funnel(window: nil)
      {
        key: "ship_review",
        title: "Ship Certification → Payout",
        subtitle: "Shipping, certification, and payout",
        steps: starter_steps(window: window) + ship_certification_to_payout_steps(window: window)
      }
    end

    def devlog_ship_show_and_tell_funnel(window: nil)
      {
        key: "ship_to_show_and_tell",
        title: "projects → ship → show & tell",
        subtitle: "First project, first ship, first show & tell attendance",
        steps: starter_steps(window: window) + devlog_ship_show_and_tell_steps(window: window)
      }
    end

    def count_funnel_event_steps(step_keys, window: nil)
      FunnelEvents::StepCounter.count_distinct_by_group(
        relation: FunnelEvent,
        group_column: :event_name,
        distinct_column: :email,
        step_keys: step_keys,
        window: window
      )
    end

    def p2p_funnel_steps(window: nil)
      project_created = count_funnel_event_steps([ "project_created" ], window: window).first
      devlog_created = count_funnel_event_steps([ "devlog_created" ], window: window).first

      [
        project_created,
        devlog_created,
        { name: "project_shipped", count: count_first_time_project_shipped(window: window) },
        { name: "project_paid_out", count: count_first_time_project_paid_out(window: window) },
        { name: "order_placed", count: count_first_time_order_placed(window: window) },
        { name: "order_fulfilled", count: count_first_time_order_fulfilled(window: window) }
      ]
    end

    def devlog_ship_show_and_tell_steps(window: nil)
      project_created = count_funnel_event_steps([ "project_created" ], window: window).first
      devlog_created = count_funnel_event_steps([ "devlog_created" ], window: window).first

      [
        project_created,
        devlog_created,
        { name: "project_shipped", count: count_first_time_project_shipped(window: window) },
        { name: "show_and_tell_attended", count: count_first_time_show_and_tell_attended(window: window) }
      ]
    end

    def count_first_time_show_and_tell_attended(window: nil)
      attendances = ShowAndTellAttendance.where.not(user_id: nil).where.not(date: nil)

      first_attendance_by_user = attendances
                                 .select("show_and_tell_attendances.user_id AS user_id, MIN(show_and_tell_attendances.date) AS first_on")
                                 .group("show_and_tell_attendances.user_id")

      subquery_sql = first_attendance_by_user.to_sql
      scoped = ShowAndTellAttendance.unscoped.from("(#{subquery_sql}) AS first_show_and_tells")
      if window.present?
        scoped = scoped.where("first_show_and_tells.first_on BETWEEN ? AND ?", window.begin.to_date, window.end.to_date)
      end
      scoped.count
    end

    def count_first_time_project_shipped(window: nil)
      ship_posts = Post.where(postable_type: "Post::ShipEvent")
      ship_posts = ship_posts.where.not(user_id: nil)

      initial_ship_posts = ship_posts.where(
        "posts.created_at = (SELECT MIN(p2.created_at) FROM posts p2 WHERE p2.project_id = posts.project_id AND p2.postable_type = ?)",
        "Post::ShipEvent"
      )

      first_ship_by_user = initial_ship_posts
                           .select("posts.user_id AS user_id, MIN(posts.created_at) AS first_at")
                           .group("posts.user_id")

      subquery_sql = first_ship_by_user.to_sql
      scoped = Post.unscoped.from("(#{subquery_sql}) AS first_ships")
      if window.present?
        scoped = scoped.where("first_ships.first_at BETWEEN ? AND ?", window.begin, window.end)
      end
      scoped.count
    end

    def count_first_time_project_paid_out(window: nil)
      payout_entries = LedgerEntry
                       .where(ledgerable_type: "Post::ShipEvent", created_by: "ship_event_payout")
                       .where("amount > 0")

      first_payout_by_user = payout_entries
                             .select("ledger_entries.user_id AS user_id, MIN(ledger_entries.created_at) AS first_at")
                             .group("ledger_entries.user_id")

      subquery_sql = first_payout_by_user.to_sql
      scoped = LedgerEntry.unscoped.from("(#{subquery_sql}) AS first_payouts")
      if window.present?
        scoped = scoped.where("first_payouts.first_at BETWEEN ? AND ?", window.begin, window.end)
      end
      scoped.count
    end

    def count_first_time_order_placed(window: nil)
      base = ShopOrder.real

      first_order_by_user = base
                            .select("shop_orders.user_id AS user_id, MIN(shop_orders.created_at) AS first_at")
                            .group("shop_orders.user_id")

      subquery_sql = first_order_by_user.to_sql
      scoped = ShopOrder.unscoped.from("(#{subquery_sql}) AS first_orders")
      if window.present?
        scoped = scoped.where("first_orders.first_at BETWEEN ? AND ?", window.begin, window.end)
      end
      scoped.count
    end

    def count_first_time_order_fulfilled(window: nil)
      base = ShopOrder.real.where.not(fulfilled_at: nil)

      first_fulfilled_by_user = base
                                .select("shop_orders.user_id AS user_id, MIN(shop_orders.fulfilled_at) AS first_at")
                                .group("shop_orders.user_id")

      subquery_sql = first_fulfilled_by_user.to_sql
      scoped = ShopOrder.unscoped.from("(#{subquery_sql}) AS first_fulfilled_orders")
      if window.present?
        scoped = scoped.where("first_fulfilled_orders.first_at BETWEEN ? AND ?", window.begin, window.end)
      end
      scoped.count
    end

    def sidequest_funnel_steps(window: nil)
      base = SidequestEntry.joins(project: :memberships).merge(Project::Membership.owner)

      submitted = base
      submitted = submitted.where(created_at: window) if window.present?
      submitted_count = submitted.distinct.count("project_memberships.user_id")

      reviewed = base.where.not(reviewed_at: nil)
      if window.present?
        reviewed = reviewed.where(reviewed_at: window)
      end
      reviewed_count = reviewed.distinct.count("project_memberships.user_id")

      approved_count = reviewed.where(aasm_state: "approved").distinct.count("project_memberships.user_id")

      [
        { name: "quest_entry_submitted", count: submitted_count },
        { name: "quest_entry_reviewed", count: reviewed_count },
        { name: "quest_entry_approved", count: approved_count }
      ]
    end

    def voting_funnel_steps(extra_steps: [], window: nil)
      votes = Vote.all
      votes = votes.where(created_at: window) if window.present?

      voted_users = votes.distinct.count(:user_id)
      fifteen_vote_users = votes.group(:user_id).having("COUNT(*) >= 15").count.size

      steps = [
        { name: "vote_casted", count: voted_users },
        { name: "15_votes_casted", count: fifteen_vote_users }
      ]

      if extra_steps.present?
        steps += extra_steps
      end

      steps
    end

    def verdict_transition_step(name:, from_values:, to_value:, window: nil)
      { name: name, count: count_verdict_transitions(from_values: from_values, to_value: to_value, window: window) }
    end

    def count_verdict_transitions(from_values:, to_value:, window: nil)
      from_values = Array(from_values).map(&:to_s)

      versions = PaperTrail::Version
        .joins("INNER JOIN user_vote_verdicts ON user_vote_verdicts.id::text = versions.item_id")
        .where(item_type: "User::VoteVerdict", event: "update")
        .where("object_changes ? 'verdict'")
        .where("jsonb_typeof(object_changes->'verdict') = 'array'")
        .where("object_changes->'verdict'->>1 = ?", to_value.to_s)

      if from_values.present?
        versions = versions.where("object_changes->'verdict'->>0 IN (?)", from_values)
      end

      versions = versions.where(created_at: window) if window.present?

      versions.distinct.count("user_vote_verdicts.user_id")
    end

    def ship_certification_to_payout_steps(window: nil)
      ships = Post::ShipEvent.joins(:post)
      ships = ships.where(posts: { created_at: window }) if window.present?

      shipped_users = ships.distinct.count("posts.user_id")
      certified_users = ships.where(certification_status: "approved").distinct.count("posts.user_id")
      paid_users = ships.where.not(payout: nil).distinct.count("posts.user_id")

      [
        { name: "ship_event_created", count: shipped_users },
        { name: "ship_event_certified", count: certified_users },
        { name: "ship_event_paid", count: paid_users }
      ]
    end
  end
end
