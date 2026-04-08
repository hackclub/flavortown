module LockinWeeksHelper
  LOCKIN_WEEKS = [
    { num: 1, start: "2026-03-29 00:00:00 EST", end: "2026-04-08 23:59:59 EST" },
    { num: 2, start: "2026-04-09 00:00:00 EST", end: "2026-04-15 23:59:59 EST" },
    { num: 3, start: "2026-04-16 00:00:00 EST", end: "2026-04-22 23:59:59 EST" },
    { num: 4, start: "2026-04-23 00:00:00 EST", end: "2026-04-29 23:59:59 EST" }
  ].map { |w|
    { num: w[:num], start: Time.zone.parse(w[:start]), end: Time.zone.parse(w[:end]) }
  }.freeze

  def lockin_weeks
    LOCKIN_WEEKS
  end


  def lockin_active_week(now = Time.current)
    return 0 if now < LOCKIN_WEEKS.first[:start]

    LOCKIN_WEEKS.each do |w|
      return w[:num] if now <= w[:end]
    end

    5
  end

  def lockin_current_week_bounds(now = Time.current)
    active = lockin_active_week(now)

    week = case active
    when 0 then LOCKIN_WEEKS.first
    when 5 then LOCKIN_WEEKS.last
    else LOCKIN_WEEKS.find { |w| w[:num] == active }
    end

    { start: week[:start], end: week[:end] }
  end


  def lockin_display_week(now = Time.current)
    [ [ lockin_active_week(now), 1 ].max, 4 ].min
  end

  def lockin_status_text(now = Time.current)
    case lockin_active_week(now)
    when 0 then "Enlisting"
    when 1..4 then "In Progress (Week #{lockin_active_week(now)})"
    else "Ended"
    end
  end
end
