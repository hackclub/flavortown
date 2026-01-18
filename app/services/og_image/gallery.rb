module OgImage
  class Gallery < IndexPage
    MIN_WEEKLY_THRESHOLD = 5
    MIN_TOTAL_THRESHOLD = 10

    PREVIEWS = {
      "default" => -> { new(weekly_count: 42, total_count: 500) },
      "low_weekly" => -> { new(weekly_count: 3, total_count: 150) },
      "low_total" => -> { new(weekly_count: 1, total_count: 5) }
    }.freeze

    def initialize(weekly_count: 0, total_count: 0)
      subtitle = build_subtitle(weekly_count, total_count)
      super(title: "Gallery", subtitle: subtitle)
    end

    private

    def build_subtitle(weekly_count, total_count)
      if weekly_count >= MIN_WEEKLY_THRESHOLD
        "#{weekly_count} projects built this week"
      elsif total_count >= MIN_TOTAL_THRESHOLD
        "#{total_count} projects built"
      end
    end
  end
end
