# frozen_string_literal: true

# Flavortown has ended, so new visits and events are no longer recorded. The
# existing ahoy data stays readable (e.g. for Privacy::Eraser) through
# Ahoy::Visit and Ahoy::Event.
class Ahoy::Store < Ahoy::BaseStore
  def track_visit(_data)
  end

  def track_event(_data)
  end
end

Ahoy.api = false
Ahoy.geocode = false
