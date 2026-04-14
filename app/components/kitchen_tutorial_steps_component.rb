class KitchenTutorialStepsComponent < ApplicationComponent
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag

  def initialize(tutorial_steps:, completed_steps:, current_user:)
    @tutorial_steps = tutorial_steps
    @completed_steps = completed_steps
    @current_user = current_user
  end

  def view_template
    div(data: { controller: "tutorial-video-modal" }) do
      turbo_frame_tag("tutorial-steps-container") do
        details(
          class: "tutorial-steps",
          data: {
            controller: "tutorial-steps-expand",
            tutorial_steps_expand_auto_expand_value: !all_completed?,
            tutorial_steps_expand_delay_value: 500
          }
        ) do
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

          p(class: "tutorial-steps__subtext") do
            "Additional cookies are rewarded upon completion of various stages of the tutorial, so complete all 8 steps!"
          end

          div(class: "tutorial-steps__grid") do
            @tutorial_steps.each do |step|
              render_step_card(step)
            end
          end
        end
      end

      render_tutorial_video_modal
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

    div(class: card_classes, data: { tutorial_step: step.slug }) do
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
    if verb == :modal && deps_ok
      div(class: "state-card__cta") do
        button(
          type: "button",
          class: "btn btn--borderless btn--bg_yellow",
          data: {
            action: "click->tutorial-video-modal#open",
            tutorial_video_modal_complete_url_param: helpers.complete_user_tutorial_step_path(step.slug),
            tutorial_video_modal_video_url_param: step.video_url
          }
        ) do
          span { completed ? "Watch again" : "Start" }
          inline_svg_tag("icons/right-arrow.svg")
        end
      end
    elsif deps_ok && !completed
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

  def render_tutorial_video_modal
    dialog(
      id: "tutorial-video-modal",
      class: "tutorial-video-modal",
      data: { tutorial_video_modal_target: "dialog", action: "click->tutorial-video-modal#closeOnBackdrop" }
    ) do
      div(class: "tutorial-video-modal__content") do
        button(
          type: "button",
          class: "tutorial-video-modal__close tutorial-video-modal__close--corner",
          data: { action: "click->tutorial-video-modal#close" }
        ) { "×" }
        div(class: "tutorial-video-modal__video-wrapper") do
          div(class: "tutorial-video-modal__body") do
            iframe(
              title: "vimeo-player",
              src: "",
              frameborder: "0",
              referrerpolicy: "strict-origin-when-cross-origin",
              allow: "autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share",
              allowfullscreen: true,
              data: { tutorial_video_modal_target: "iframe" }
            )
          end
        end
      end
    end
  end
end
