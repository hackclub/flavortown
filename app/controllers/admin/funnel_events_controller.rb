# frozen_string_literal: true

module Admin
  class FunnelEventsController < Admin::ApplicationController
    FUNNELS = [
      { key: "project", title: "P2P", subtitle: "(start) project to prize", kind: :p2p },
      { key: "sidequests", title: "Sidequest Flow", subtitle: "Sidequest Funnel", kind: :sidequest },
      { key: "voting_curse", title: "Voting (Curse)", subtitle: "Casting votes → curse flow", kind: :voting, variant: :curse },
      { key: "voting_blessing", title: "Voting (Blessing)", subtitle: "Casting votes → blessing flow", kind: :voting, variant: :blessing },
      { key: "ship_review", title: "Ship Certification → Payout", subtitle: "Shipping → payout", kind: :ship_review },
      { key: "ship_to_show_and_tell", title: "projects → ship → show & tell", subtitle: "Project → S&T", kind: :ship_to_show_and_tell }
    ].freeze

    BUILDERS = {
      p2p: :p2p_steps,
      sidequest: :sidequest_steps,
      ship_review: :ship_review_steps,
      ship_to_show_and_tell: :ship_show_tell_steps,
      voting: :voting_steps
    }.freeze

    VOTING = {
      curse: [
        ["got_cursed", %w[neutral blessed], "cursed"],
        ["curse_removed", ["cursed"], "neutral"]
      ],
      blessing: [
        ["got_blessed", %w[neutral cursed], "blessed"],
        ["blessing_removed", ["blessed"], "neutral"]
      ]
    }.freeze

    def index
      authorize :admin, :access_super_mega_dashboard?

      @range_key = FunnelEvents::TimeRange.key(params[:range])
      @window = FunnelEvents::TimeRange.window(@range_key)

      @funnels = FUNNELS.map { |f| build_funnel(f, @window) }
    end

    private

    def build_funnel(defn, window)
      {
        key: defn[:key],
        title: defn[:title],
        subtitle: defn[:subtitle],
        steps: starter_steps(window) + send(BUILDERS.fetch(defn[:kind]), defn, window)
      }
    end

    def starter_steps(window)
      count_steps(%w[start_flow_started identity_verified], window)
    end

    def event_step(name, window)
      count_steps([name], window).first
    end

    def count_steps(keys, window)
      FunnelEvents::StepCounter.count_distinct_by_group(
        relation: FunnelEvent,
        group_column: :event_name,
        distinct_column: :email,
        step_keys: keys,
        window: window
      )
    end

    def first_time_count(relation:, group:, time:, model:, alias_name:, window:)
      count_first_time_by_user(
        base_relation: relation,
        group_select: group,
        min_select: time,
        window: window,
        from_model: model,
        subquery_alias: alias_name,
        time_alias: "first_at",
        window_begin: window&.begin,
        window_end: window&.end
      )
    end

    def count_first_time_by_user(base_relation:, group_select:, min_select:, window:, from_model:, subquery_alias:, time_alias:, window_begin:, window_end:)
      sub = base_relation
        .select("#{group_select}, MIN(#{min_select}) AS #{time_alias}")
        .group(group_select)

      scoped = from_model.unscoped
        .from("(#{sub.to_sql}) AS #{subquery_alias}")

      scoped = scoped.where("#{subquery_alias}.#{time_alias} BETWEEN ? AND ?", window_begin, window_end) if window
      scoped.count
    end

    def p2p_steps(_, window)
      [
        event_step("project_created", window),
        event_step("devlog_created", window),
        { name: "project_shipped", count: first_time_count(
          relation: Post.where(postable_type: "Post::ShipEvent").where.not(user_id: nil)
            .where("posts.created_at = (SELECT MIN(p2.created_at) FROM posts p2 WHERE p2.project_id = posts.project_id AND p2.postable_type = ?)", "Post::ShipEvent"),
          group: "posts.user_id",
          time: "posts.created_at",
          model: Post,
          alias_name: "first_ships",
          window: window
        )},
        { name: "project_paid_out", count: first_time_count(
          relation: LedgerEntry.where(ledgerable_type: "Post::ShipEvent", created_by: "ship_event_payout").where("amount > 0"),
          group: "ledger_entries.user_id",
          time: "ledger_entries.created_at",
          model: LedgerEntry,
          alias_name: "first_payouts",
          window: window
        )},
        { name: "order_placed", count: first_time_count(
          relation: ShopOrder.real,
          group: "shop_orders.user_id",
          time: "shop_orders.created_at",
          model: ShopOrder,
          alias_name: "first_orders",
          window: window
        )},
        { name: "order_fulfilled", count: first_time_count(
          relation: ShopOrder.real.where.not(fulfilled_at: nil),
          group: "shop_orders.user_id",
          time: "shop_orders.fulfilled_at",
          model: ShopOrder,
          alias_name: "first_fulfilled_orders",
          window: window
        )}
      ]
    end

    def ship_show_tell_steps(_, window)
      [
        event_step("project_created", window),
        event_step("devlog_created", window),
        { name: "project_shipped", count: p2p_steps(nil, window)[2][:count] },
        { name: "showed_and_told", count: first_time_count(
          relation: ShowAndTellAttendance.where.not(user_id: nil, date: nil),
          group: "show_and_tell_attendances.user_id",
          time: "show_and_tell_attendances.date",
          model: ShowAndTellAttendance,
          alias_name: "first_st",
          window: window
        )}
      ]
    end

    def ship_review_steps(_, window)
      ships = Post::ShipEvent.joins(:post)
      ships = ships.where(posts: { created_at: window }) if window

      [
        { name: "ship_event_created", count: ships.distinct.count("posts.user_id") },
        { name: "ship_event_certified", count: ships.where(certification_status: "approved").distinct.count("posts.user_id") },
        { name: "ship_event_paid", count: ships.where.not(payout: nil).distinct.count("posts.user_id") }
      ]
    end

    def sidequest_steps(_, window)
      base = SidequestEntry.joins(project: :memberships).merge(Project::Membership.owner)

      submitted = window ? base.where(created_at: window) : base
      reviewed  = window ? base.where.not(reviewed_at: nil).where(reviewed_at: window) : base.where.not(reviewed_at: nil)

      [
        { name: "quest_entry_submitted", count: submitted.distinct.count("project_memberships.user_id") },
        { name: "quest_entry_reviewed", count: reviewed.distinct.count("project_memberships.user_id") },
        { name: "quest_entry_approved", count: reviewed.where(aasm_state: "approved").distinct.count("project_memberships.user_id") }
      ]
    end

    def voting_steps(defn, window)
      votes = window ? Vote.where(created_at: window) : Vote.all

      base_steps = [
        { name: "vote_casted", count: votes.distinct.count(:user_id) },
        { name: "15_votes_casted", count: votes.group(:user_id).having("COUNT(*) >= 15").count.size }
      ]

      extra = VOTING.fetch(defn[:variant]).map do |name, from, to|
        {
          name: name,
          count: count_verdict_transitions(from_values: from, to_value: to, window: window)
        }
      end

      base_steps + extra
    end

    def count_verdict_transitions(from_values:, to_value:, window:)
      versions = PaperTrail::Version
        .joins("INNER JOIN user_vote_verdicts ON user_vote_verdicts.id::text = versions.item_id")
        .where(item_type: "User::VoteVerdict", event: "update")
        .where("object_changes ? 'verdict'")
        .where("jsonb_typeof(object_changes->'verdict') = 'array'")
        .where("object_changes->'verdict'->>1 = ?", to_value.to_s)

      versions = versions.where("object_changes->'verdict'->>0 IN (?)", Array(from_values)) if from_values.present?
      versions = versions.where(created_at: window) if window

      versions.distinct.count("user_vote_verdicts.user_id")
    end
  end
end