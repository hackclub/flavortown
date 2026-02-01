class MajorityJudgmentService
  def self.call(ship_event)
    new(ship_event).call
  end

  def self.refresh_all!
    medians_by_ship_event, all_medians_by_category, all_overall_scores = build_all_medians

    Post::ShipEvent.find_each do |ship_event|
      metrics = medians_by_ship_event[ship_event.id]
      if metrics
        percentiles = build_percentiles(metrics[:medians], all_medians_by_category)
        overall_percentile = percentile_rank(metrics[:overall_score], all_overall_scores)
        attrs = persisted_attributes(
          medians: metrics[:medians],
          overall_score: metrics[:overall_score],
          percentiles: percentiles,
          overall_percentile: overall_percentile
        )
      else
        attrs = empty_persisted_attributes
      end

      ship_event.update_columns(attrs.merge(updated_at: Time.current))

      next unless ship_event.votes_count.to_i >= Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT

      ShipEventPayoutCalculator.apply!(ship_event)
    end
  end

  def initialize(ship_event)
    @ship_event = ship_event
  end

  def call
    scores = @ship_event.votes.legitimate.pluck(*Vote.score_columns)
    return empty_result if scores.empty?

    medians = build_medians(scores)

    overall_score = self.class.average(medians.values.compact)
    percentiles, overall_percentile = calculate_percentiles(medians, overall_score)

    {
      medians: medians,
      overall_score: overall_score,
      percentiles: percentiles,
      overall_percentile: overall_percentile
    }
  end

  private

  def empty_result
    {
      medians: Vote.enabled_categories.index_with { nil },
      overall_score: nil,
      percentiles: Vote.enabled_categories.index_with { nil },
      overall_percentile: nil
    }
  end

  def calculate_percentiles(medians, overall_score)
    all_medians_by_category, all_overall_scores = self.class.all_median_values

    percentiles = self.class.build_percentiles(medians, all_medians_by_category)

    overall_percentile = self.class.percentile_rank(overall_score, all_overall_scores)

    [ percentiles, overall_percentile ]
  end

  def build_medians(scores)
    Vote.enabled_categories.each_with_index.to_h do |category, index|
      column_scores = scores.map { |row| row[index] }.compact.sort
      [ category, self.class.median(column_scores) ]
    end
  end

  def self.all_median_values
    all_scores = Vote.legitimate.pluck(:ship_event_id, *Vote.score_columns)
    scores_by_ship_event = all_scores.group_by(&:first).transform_values do |rows|
      rows.map { |row| row.drop(1) }
    end

    medians_by_category = Vote.enabled_categories.index_with { [] }
    overall_scores = []

    scores_by_ship_event.each_value do |scores|
      medians = build_medians_from_scores(scores)

      medians.each do |category, value|
        medians_by_category[category] << value if value
      end

      overall = average(medians.values.compact)
      overall_scores << overall if overall
    end

    [ medians_by_category, overall_scores ]
  end

  def self.build_percentiles(medians, all_medians_by_category)
    Vote.enabled_categories.each_with_object({}) do |category, result|
      result[category] = percentile_rank(medians[category], all_medians_by_category[category])
    end
  end

  def self.build_all_medians
    all_scores = Vote.legitimate.pluck(:ship_event_id, *Vote.score_columns)
    scores_by_ship_event = all_scores.group_by(&:first).transform_values do |rows|
      rows.map { |row| row.drop(1) }
    end

    medians_by_ship_event = {}
    medians_by_category = Vote.enabled_categories.index_with { [] }
    overall_scores = []

    scores_by_ship_event.each do |ship_event_id, scores|
      medians = build_medians_from_scores(scores)
      overall = average(medians.values.compact)

      medians_by_ship_event[ship_event_id] = {
        medians: medians,
        overall_score: overall
      }

      medians.each do |category, value|
        medians_by_category[category] << value if value
      end

      overall_scores << overall if overall
    end

    [ medians_by_ship_event, medians_by_category, overall_scores ]
  end

  def self.build_medians_from_scores(scores)
    Vote.enabled_categories.each_with_index.to_h do |category, index|
      column_scores = scores.map { |row| row[index] }.compact.sort
      [ category, median(column_scores) ]
    end
  end

  def self.persisted_attributes(medians:, overall_score:, percentiles:, overall_percentile:)
    {
      originality_median: medians[:originality],
      technical_median: medians[:technical],
      usability_median: medians[:usability],
      storytelling_median: medians[:storytelling],
      overall_score: overall_score,
      originality_percentile: percentiles[:originality],
      technical_percentile: percentiles[:technical],
      usability_percentile: percentiles[:usability],
      storytelling_percentile: percentiles[:storytelling],
      overall_percentile: overall_percentile
    }
  end

  def self.empty_persisted_attributes
    {
      originality_median: nil,
      technical_median: nil,
      usability_median: nil,
      storytelling_median: nil,
      overall_score: nil,
      originality_percentile: nil,
      technical_percentile: nil,
      usability_percentile: nil,
      storytelling_percentile: nil,
      overall_percentile: nil
    }
  end

  def self.percentile_rank(value, all_values)
    return nil if value.nil? || all_values.empty?

    count_below = 0
    count_equal = 0

    all_values.each do |current|
      if current < value
        count_below += 1
      elsif current == value
        count_equal += 1
      end
    end

    return 50.0 if count_below.zero? && count_equal == all_values.length

    ((count_below + 0.5 * count_equal) / all_values.length.to_f * 100).round(2)
  end

  def self.median(values)
    return nil if values.empty?

    mid = values.length / 2
    return values[mid] if values.length.odd?

    (values[mid - 1] + values[mid]) / 2.0
  end

  def self.average(values)
    return nil if values.empty?

    values.sum.to_f / values.length
  end
end
