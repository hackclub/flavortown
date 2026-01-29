module Admin
  class ShipEventScoresController < ApplicationController
    SORTABLE_COLUMNS = {
      "overall_score" => "overall_score",
      "overall_percentile" => "overall_percentile",
      "originality_median" => "originality_median",
      "technical_median" => "technical_median",
      "usability_median" => "usability_median",
      "storytelling_median" => "storytelling_median",
      "originality_percentile" => "originality_percentile",
      "technical_percentile" => "technical_percentile",
      "usability_percentile" => "usability_percentile",
      "storytelling_percentile" => "storytelling_percentile",
      "votes_count" => "votes_count",
      "created_at" => "created_at"
    }.freeze

    helper_method :sort_params

    def index
      authorize :admin, :access_admin_endpoints?

      @sort_column = SORTABLE_COLUMNS.fetch(params[:sort], "overall_percentile")
      @direction = params[:direction] == "asc" ? "asc" : "desc"

      @ship_events = Post::ShipEvent
        .includes(post: :project)
        .where("votes_count > 10")
        .order(Arel.sql("#{@sort_column} #{@direction} NULLS LAST"))

      @distribution = build_distribution(@ship_events)
      @convergence_data = build_convergence(@ship_events)
    end

    private

    def sort_params(column)
      current_direction = @direction || "desc"
      direction = params[:sort] == column && current_direction == "desc" ? "asc" : "desc"
      { sort: column, direction: direction }
    end

    def build_distribution(ship_events)
      percentiles = ship_events.pluck(:overall_percentile).compact
      scores = ship_events.pluck(:overall_score).compact

      {
        overall_percentile: bucket_percentiles(percentiles),
        overall_score: bucket_scores(scores)
      }
    end

    def bucket_percentiles(values)
      buckets = Array.new(10, 0)
      values.each do |value|
        index = [ (value / 10).floor, 9 ].min
        buckets[index] += 1
      end
      buckets
    end

    def bucket_scores(values)
      buckets = Array.new(6, 0)
      values.each do |value|
        index = value.to_f.ceil.clamp(1, 6) - 1
        buckets[index] += 1
      end
      buckets
    end

    def build_convergence(ship_events)
      ship_event_ids = ship_events.pluck(:id)
      return {} if ship_event_ids.empty?

      vote_rows = Vote
        .where(ship_event_id: ship_event_ids)
        .order(:created_at)
        .pluck(:ship_event_id, *Vote.score_columns, :created_at)

      grouped = vote_rows.group_by(&:first)
      grouped.each_with_object({}) do |(ship_event_id, rows), result|
        series = []
        scores_by_category = Vote.enabled_categories.index_with { [] }

        rows.each_with_index do |row, index|
          scores = row[1, Vote.score_columns.length]

          Vote.enabled_categories.each_with_index do |category, category_index|
            value = scores[category_index]
            scores_by_category[category] << value if value
          end

          medians = Vote.enabled_categories.map do |category|
            MajorityJudgmentService.median(scores_by_category[category].sort)
          end.compact

          series << {
            x: index + 1,
            y: medians.any? ? (medians.sum / medians.length.to_f).round(2) : nil
          }
        end

        result[ship_event_id] = series
      end
    end
  end
end
