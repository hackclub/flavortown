# frozen_string_literal: true

class ModalComponent < ViewComponent::Base
  renders_one :body

  attr_reader :id, :title, :description

  def initialize(id:, title:, description: nil, modal_class: nil, data: {})
    @id = id
    @title = title
    @description = description
    @modal_class = modal_class
    @data = data || {}
    @action_buttons = []
    @action_class_name = nil
  end

  def dialog_classes
    class_names("modal", @modal_class)
  end

  def dialog_data
    { controller: "modal" }.merge(@data)
  end

  def body_content
    body? ? body : content
  end

  def has_actions?
    @action_buttons.any?
  end

  def action_classes
    class_names("modal__actions", @action_class_name)
  end

  def with_actions(class_name: nil)
    @action_class_name = class_name
    nil
  end

  def with_button(text: nil, color: :brown, variant: :borderless, **options)
    @action_buttons << ButtonComponent.new(text: text, color: color, variant: variant, **options)
    nil
  end

  def with_submit_button(text: "Submit", color: :blue, **options)
    with_button(text: text, color: color, variant: :borderless, type: :submit, **options)
  end

  def with_close_button(text: "Close", **options)
    with_button(text: text, color: :brown, variant: :borderless, data: { action: "modal#close" }, **options)
  end

  def with_cancel_button(text: "Cancel", color: :brown, **options)
    with_button(text: text, color: color, variant: :borderless, data: { action: "modal#close" }, **options)
  end

  def with_submit_and_cancel(
    submit_text: "Submit",
    submit_options: {},
    cancel_text: "Cancel",
    cancel_options: {}
  )
    with_submit_button(text: submit_text, **submit_options)
    with_cancel_button(text: cancel_text, **cancel_options)
  end

  def action_buttons
    @action_buttons
  end
end
