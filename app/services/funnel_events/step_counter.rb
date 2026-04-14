# frozen_string_literal: true

module FunnelEvents
  class StepCounter
    def self.from_grouped_counts(step_keys, grouped_counts)
      step_keys.map do |key|
        {
          name: key,
          count: grouped_counts[key].to_i
        }
      end
    end

    def self.count_distinct_by_group(relation:, group_column:, distinct_column:, step_keys:, window: nil)
      scope = relation.where(group_column => step_keys)
      scope = scope.where(created_at: window) if window.present?

      grouped_counts = scope.group(group_column).distinct.count(distinct_column)
      from_grouped_counts(step_keys, grouped_counts)
    end
  end
end
