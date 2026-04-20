module SidequestsHelper
  CHALLENGER_CYCLES = [
    {
      number: 1,
      starts_on: Date.new(2026, 4, 16),
      ends_on: Date.new(2026, 4, 20),
      theme: "something an astronaut would use while on a mission"
    },
    {
      number: 2,
      starts_on: Date.new(2026, 4, 21),
      ends_on: Date.new(2026, 4, 25),
      theme: "something that would help civilization survive on the moon"
    },
    {
      number: 3,
      starts_on: Date.new(2026, 4, 26),
      ends_on: Date.new(2026, 4, 30),
      theme: "something that would help scientists study space better"
    }
  ].freeze

  def render_sidequest_card(sidequest)
    partial = "sidequests/#{sidequest.slug}"
    partial = "sidequests/default" unless lookup_context.exists?(partial, [], true)
    render partial: partial, locals: { sidequest: sidequest }
  end

  def challenger_current_cycle(date = Date.current)
    CHALLENGER_CYCLES.find do |cycle|
      date.between?(cycle[:starts_on], cycle[:ends_on])
    end
  end

  def challenger_current_cycle_label(date = Date.current)
    cycle = challenger_current_cycle(date)
    return "No active cycle" unless cycle

    "Cycle #{cycle[:number]}: #{cycle[:theme]}"
  end
end
