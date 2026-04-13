# frozen_string_literal: true

module FunnelEvents
  class TimeRange
    OPTIONS = {
      "24h" => { label: "Last 24 hours", window: -> { 24.hours.ago..Time.current } },
      "1w"  => { label: "Last week", window: -> { 7.days.ago..Time.current } },
      "1m"  => { label: "Last month", window: -> { 30.days.ago..Time.current } },
      "all" => { label: "All time", window: -> { nil } }
    }.freeze

    def self.key(param)
      value = param.to_s
      OPTIONS.key?(value) ? value : "all"
    end

    def self.window(key)
      OPTIONS.fetch(key).fetch(:window).call
    end

    def self.options_for_select
      OPTIONS.map { |k, v| [ v.fetch(:label), k ] }
    end
  end
end
