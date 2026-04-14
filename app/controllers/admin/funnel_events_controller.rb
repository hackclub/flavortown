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
        [ "got_cursed", :ever_had_verdict, "cursed" ],
        [ "curse_removed", :ever_left_verdict, "cursed" ]
      ],
      blessing: [
        [ "got_blessed", :ever_had_verdict, "blessed" ],
        [ "blessing_removed", :ever_left_verdict, "blessed" ]
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
      count_steps([ name ], window).first
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
        group_attr: group,
        min_attr: time,
        window: window,
        from_model: model,
        subquery_alias: alias_name,
        time_alias: "first_at",
        window_begin: window&.begin,
        window_end: window&.end
      )
    end

    def count_first_time_by_user(base_relation:, group_attr:, min_attr:, window:, from_model:, subquery_alias:, time_alias:, window_begin:, window_end:)
      subquery_alias = subquery_alias.to_s
      time_alias = time_alias.to_s

      sub = base_relation
        .select(group_attr, Arel::Nodes::NamedFunction.new("MIN", [ min_attr ]).as(time_alias))
        .group(group_attr)

      scoped = from_model.unscoped.from(sub, subquery_alias)

      if window
        sub_table = Arel::Table.new(subquery_alias)
        scoped = scoped.where(sub_table[time_alias].gteq(window_begin)).where(sub_table[time_alias].lteq(window_end))
      end

      scoped.count
    end

    def p2p_steps(_, window)
      [
        event_step("project_created", window),
        event_step("devlog_created", window),
        { name: "project_shipped", count: first_time_count(
          relation: Post.where(postable_type: "Post::ShipEvent").where.not(user_id: nil)
            .where("posts.created_at = (SELECT MIN(p2.created_at) FROM posts p2 WHERE p2.project_id = posts.project_id AND p2.postable_type = ?)", "Post::ShipEvent"),
          group: Post.arel_table[:user_id],
          time: Post.arel_table[:created_at],
          model: Post,
          alias_name: "first_ships",
          window: window
        ) },
        { name: "project_paid_out", count: first_time_count(
          relation: LedgerEntry.where(ledgerable_type: "Post::ShipEvent", created_by: "ship_event_payout").where("amount > 0"),
          group: LedgerEntry.arel_table[:user_id],
          time: LedgerEntry.arel_table[:created_at],
          model: LedgerEntry,
          alias_name: "first_payouts",
          window: window
        ) },
        { name: "order_placed", count: first_time_count(
          relation: ShopOrder.real,
          group: ShopOrder.arel_table[:user_id],
          time: ShopOrder.arel_table[:created_at],
          model: ShopOrder,
          alias_name: "first_orders",
          window: window
        ) },
        { name: "order_fulfilled", count: first_time_count(
          relation: ShopOrder.real.where.not(fulfilled_at: nil),
          group: ShopOrder.arel_table[:user_id],
          time: ShopOrder.arel_table[:fulfilled_at],
          model: ShopOrder,
          alias_name: "first_fulfilled_orders",
          window: window
        ) }
      ]
    end

    def ship_show_tell_steps(_, window)
      [
        event_step("project_created", window),
        event_step("devlog_created", window),
        { name: "project_shipped", count: p2p_steps(nil, window)[2][:count] },
        { name: "showed_and_told", count: first_time_count(
          relation: ShowAndTellAttendance.where.not(user_id: nil, date: nil),
          group: ShowAndTellAttendance.arel_table[:user_id],
          time: ShowAndTellAttendance.arel_table[:date],
          model: ShowAndTellAttendance,
          alias_name: "first_st",
          window: window
        ) }
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

      extra = VOTING.fetch(defn[:variant]).map do |name, strategy, verdict_value|
        {
          name: name,
          count: send(strategy, verdict_value)
        }
      end

      base_steps + extra
    end

    def ever_had_verdict(verdict_value)
      verdict_value = verdict_value.to_s

      current_user_ids = User::VoteVerdict
        .where(verdict: verdict_value)
        .select("user_vote_verdicts.user_id AS user_id")
        .distinct

      version_user_ids = PaperTrail::Version
        .joins("INNER JOIN user_vote_verdicts ON user_vote_verdicts.id::text = versions.item_id")
        .where(item_type: "User::VoteVerdict")
        .where("object_changes ? 'verdict'")
        .where("jsonb_typeof(object_changes->'verdict') = 'array'")
        .where(
          "(object_changes->'verdict'->>0 = :v OR object_changes->'verdict'->>1 = :v)",
          v: verdict_value
        )
        .select("DISTINCT user_vote_verdicts.user_id AS user_id")

      union_sql = "(#{current_user_ids.to_sql} UNION #{version_user_ids.to_sql}) AS verdict_user_ids"
      User::VoteVerdict.unscoped.from(Arel.sql(union_sql)).select(Arel.sql("verdict_user_ids.user_id")).count
    end

    def ever_left_verdict(verdict_value)
      verdict_value = verdict_value.to_s

      PaperTrail::Version
        .joins("INNER JOIN user_vote_verdicts ON user_vote_verdicts.id::text = versions.item_id")
        .where(item_type: "User::VoteVerdict")
        .where("object_changes ? 'verdict'")
        .where("jsonb_typeof(object_changes->'verdict') = 'array'")
        .where("object_changes->'verdict'->>0 = ?", verdict_value)
        .where("object_changes->'verdict'->>1 IS DISTINCT FROM ?", verdict_value)
        .distinct
        .count("user_vote_verdicts.user_id")
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
