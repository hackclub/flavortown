class KitchenHelpCardsComponent < ApplicationComponent
  def view_template
    div(class: "kitchen-help__content") do
      h2(class: "kitchen-help__title") { "Need any help?" }
      div(class: "kitchen-help__grid") do
        div(class: "state-card state-card--neutral kitchen-help-card") do
          div(class: "state-card__title") { "Help channel on Slack" }
          div(class: "state-card__description") do
            "If you're stuck, or have any questions about Flavortown, join our Slack community and ask away in the #flavortown-help channel."
          end
          div(class: "state-card__cta") do
            a(href: "https://slack.com", class: "btn btn--borderless btn--bg_yellow") do
              span { "Join Slack" }
              # raw helpers.inline_svg_tag("icons/right-arrow.svg")
            end
          end
        end

        div(class: "state-card state-card--neutral kitchen-help-card") do
          div(class: "state-card__title") { "Email support" }
          div(class: "state-card__description") do
            plain "If you're having issues with Slack (or just prefer email), you can send a message to "
            a(href: "mailto:flavortown@hackclub.com") { "flavortown@hackclub.com" }
            plain "!"
          end
        end
      end
    end
  end
end
