# frozen_string_literal: true

class FraudHappinessComponent < ApplicationComponent
  include Phlex::Rails::Helpers::NumberWithPrecision
  include Phlex::Rails::Helpers::Truncate

  def initialize(week:, records:, avg_scores:, error: nil, prev_scores: nil)
    @week = week
    @records = records
    @avg_scores = avg_scores
    @error = error
    @prev_scores = prev_scores
  end

  def render?
    @week.present? || @error.present?
  end

  def view_template
    if @error.present?
      div(class: "fraud-happiness") do
        div(class: "fraud-happiness__error") do
          p { "Error: #{@error}" }
        end
      end
    elsif @week.present?
      div(class: "fraud-happiness") do
        h3(class: "fraud-happiness__week") do
          plain @week
          raw '<svg style="height:16px;vertical-align:middle;margin-left:4px;" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><circle cx="12" cy="12" r="9.25" stroke="currentColor" stroke-width="1.5"/><path d="M12 16.25v-5M12 7.75h.008" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/></svg>'.html_safe
        end

        if has_scores?
          div(class: "fraud-happiness__scores") do
            score_card("Overall", @avg_scores[:avg_feeling], @prev_scores&.dig(:avg_feeling))
            score_card("Shop Orders", @avg_scores[:avg_shop_order_feeling], @prev_scores&.dig(:avg_shop))
            score_card("Reports", @avg_scores[:avg_reports_order_feeling], @prev_scores&.dig(:avg_reports))
            response_card(@avg_scores[:responses_text])
          end
        else
          p(class: "fraud-happiness__empty") { "No data" }
        end
      end
    end
  end

  private

  def has_scores?
    return false unless @avg_scores.is_a?(Hash)
    return false if @avg_scores.empty?

    total = @avg_scores[:total_responses]
    total.present? && total.to_i.positive?
  end

  def pct_diff(current, prev)
    return nil unless current.is_a?(Numeric) && prev.is_a?(Numeric) && prev != 0

    diff = (((current - prev) / prev.to_f) * 100).round(1)
    [diff, diff >= 0 ? "+" : ""]
  end

  def score_card(label, value, prev_value = nil)
    div(class: "fraud-happiness__score-card") do
      h4(class: "fraud-happiness__score-card-label") { label }
      div(class: "fraud-happiness__score-card-value") do
        if value.is_a?(Float)
          plain number_with_precision(value, precision: 2)
        else
          plain value
        end
      end
      if (diff_data = pct_diff(value, prev_value))
        diff, sign = diff_data
        color = diff >= 0 ? "#10b981" : "#ef4444"
        span(style: "font-size:10px;color:#{color};") { "#{sign}#{diff}%" }
      end
    end
  end

  def response_card(responses_text)
    received, total = responses_text.to_s.split("/").map(&:to_i)
    missing = total > 0 ? total - received : 0

    div(class: "fraud-happiness__score-card") do
      h4(class: "fraud-happiness__score-card-label") { "Missing" }
      div(class: "fraud-happiness__score-card-value") do
        plain missing.to_s
      end
    end
  end
end
