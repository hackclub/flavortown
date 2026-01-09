class KitchenTutorialStepsComponent < ApplicationComponent
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(tutorial_steps:, completed_steps:, current_user:)
    @tutorial_steps = tutorial_steps
    @completed_steps = completed_steps
  end

  def view_template
    details(class: "tutorial-steps", open: !all_completed?) do
      summary(class: "tutorial-steps__header") do
        span(class: "tutorial-steps__toggle-icon") do
          inline_svg_tag("icons/chevron-down.svg", alt: "")
        end
        span(class: "tutorial-steps__title") { "Tutorial" }
        div(class: "tutorial-steps__progress") do
          span(class: "tutorial-steps__progress-text") { "#{completed_count} of #{total_count}" }
          div(class: "tutorial-steps__progress-bar") do
            div(class: "tutorial-steps__progress-fill", style: "width: #{progress_percentage}%")
          end
        end
      end

      div(class: "tutorial-steps__grid") do
        @tutorial_steps.each do |step|
          render_step_card(step)
        end
      end
    end
  end

  def all_completed? = completed_count == total_count

  private

  def render_step_card(step)
    completed = step_completed?(step)
    variant = variant_for(step)
    deps_ok = deps_satisfied?(step)
    verb = step.verb

    card_classes = "state-card state-card--#{variant} tutorial-step-card"
    card_classes += " tutorial-step-card--disabled" unless deps_ok

    div(class: card_classes) do
      div(class: "state-card__status-pill") do
        div(class: "state-card__badge") { badge_text_for(step) }
        if step.icon.present?
          div(class: "state-card__icon-circle") do
            inline_svg_tag("icons/#{step.icon}.svg", alt: "")
          end
        end
      end

      div(class: "state-card__title") { step.name }
      div(class: "state-card__description") { step.description }

      render_cta(step, completed, deps_ok, verb)
    end
  end

  def render_cta(step, completed, deps_ok, verb)
    if deps_ok && !completed
      link = step_link(step)
      return unless link

      div(class: "state-card__cta") do
        if verb == :get
          a(href: link, target: "_blank", class: "btn btn--borderless btn--bg_yellow", data: { turbo: false }) do
            span { "Start" }
            inline_svg_tag("icons/right-arrow.svg")
          end
        else
          button_to link, method: verb, class: "btn btn--borderless btn--bg_yellow", data: { turbo: false } do
            span { "Start" }
            inline_svg_tag("icons/right-arrow.svg")
          end
        end
      end
    elsif !deps_ok
      hint = unsatisfied_deps_hint(step)
      div(class: "state-card__cta") do
        span(class: "btn btn--borderless btn--bg_yellow btn--disabled") do
          span { "Locked" }
        end
        if hint
          p(class: "state-card__hint") { hint }
        end
      end
    end
  end

  def completed_count = completed_slugs.count
  def total_count = @tutorial_steps.count

  def progress_percentage
    return 0 if total_count.zero?
    (completed_count * 100.0 / total_count).round
  end

  def step_completed?(step)
    completed_slugs.include?(step.slug)
  end

  def variant_for(step)
    step_completed?(step) ? :success : :warning
  end

  def badge_text_for(step)
    step_completed?(step) ? "Done" : "Todo"
  end

  def completed_slugs
    @completed_slugs ||= @completed_steps.map { |s| s.is_a?(Symbol) ? s : s.slug } | [ :first_login ]
  end

  def deps_satisfied?(step)
    step.deps_satisfied?(completed_slugs)
  end

  def unsatisfied_deps_hint(step)
    return nil unless step.deps&.any?
    first_unsatisfied = step.deps.find { |dep| !dep.satisfied?(completed_slugs) }
    first_unsatisfied&.hint
  end

  def step_link(step)
    return nil unless step.link

    if step.link.respond_to?(:call)
      view_context.instance_exec(@current_user, &step.link)
    else
      step.link
    end
  end
end
