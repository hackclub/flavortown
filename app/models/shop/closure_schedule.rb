module Shop
  module ClosureSchedule
    TIMEZONE = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    CLOSES_AT = TIMEZONE.local(2026, 5, 9, 0, 0, 0)
    DEADLINE_LABEL = "Saturday, May 9 at 12:00 AM ET".freeze

    module_function

    def closes_at
      CLOSES_AT
    end

    def deadline_label
      DEADLINE_LABEL
    end

    def countdown_active?(reference_time = Time.current)
      reference_time < closes_at
    end
  end
end
