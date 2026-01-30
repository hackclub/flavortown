# frozen_string_literal: true

class TooltipComponent < ViewComponent::Base
  attr_reader :target_id, :position

  def initialize(target_id:, position: :top)
    @target_id = target_id
    @position = position
  end
end
