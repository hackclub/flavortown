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

  def challenger_mission_state(user = current_user)
    return :not_started unless user

    space_projects = user.projects.where("LTRIM(projects.description) LIKE ?", "#{Project::SPACE_THEMED_PREFIX}%")
    return :accomplished if space_projects.joins(:ship_events).where(post_ship_events: { certification_status: "approved" }).exists?
    return :in_progress if space_projects.exists?

    :not_started
  end

  def challenger_mission_project(user = current_user)
    return nil unless user

    user.projects
        .where("LTRIM(projects.description) LIKE ?", "#{Project::SPACE_THEMED_PREFIX}%")
        .order(updated_at: :desc)
        .first
  end

  def challenger_mission_cta_text(user = current_user)
    case challenger_mission_state(user)
    when :accomplished
      "Mission Accomplished"
    when :in_progress
      "Mission In Progress"
    else
      "Accept Mission"
    end
  end

  def challenger_mission_cta_href(user = current_user, fallback: nil)
    mission_project = challenger_mission_project(user)

    if challenger_mission_state(user) == :in_progress && mission_project.present?
      project_path(mission_project)
    else
      fallback || new_project_path(mission: "challenger")
    end
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

  def render_sidequest_card(sidequest)
    partial = "sidequests/#{sidequest.slug}"
    partial = "sidequests/default" unless lookup_context.exists?(partial, [], true)
    render partial: partial, locals: { sidequest: sidequest }
  end
end
