# frozen_string_literal: true

class FileUploadComponent < ViewComponent::Base
  COLORS = InputComponent::COLORS

  attr_reader :label, :form, :attribute, :color, :subtitle, :accept, :max_size, :max_count

  def initialize(label:, form:, attribute:, color: :yellow, subtitle: nil, accept: nil, multiple: false, direct_upload: true, max_size: nil, max_count: nil)
    @label = label
    @form = form
    @attribute = attribute
    @color = normalize_color(color)
    @subtitle = subtitle
    @accept = accept
    @multiple = multiple
    @direct_upload = direct_upload
    @max_size = max_size
    @max_count = max_count
  end

  def wrapper_classes
    class_names("input", "file-upload", "input--#{color}")
  end

  def has_subtitle?
    subtitle.present?
  end

  # TIL: strict boolean coversion
  def multiple?
    !!@multiple
  end

  def direct_upload?
    !!@direct_upload
  end

  def initial_preview_url
    record = form.object
    return nil unless record.respond_to?(attribute)
    attachment = record.public_send(attribute)
    return nil unless attachment.respond_to?(:attached?) && attachment.attached?
    if attachment.respond_to?(:attachments) # :attachment for single
      first = attachment.attachments.first
      return nil unless first
      helpers.url_for(first)
    else
      helpers.url_for(attachment)
    end
  rescue
    nil
  end

  def initial_filename
    record = form.object
    return nil unless record.respond_to?(attribute)
    attachment = record.public_send(attribute)
    return nil unless attachment.respond_to?(:attached?) && attachment.attached?
    if attachment.respond_to?(:attachments)
      att = attachment.attachments.first
      att&.blob&.filename&.to_s
    else
      blob = attachment.try(:blob)
      blob&.filename&.to_s
    end
  rescue
    nil
  end

  def initial_previews
    record = form.object
    return [] unless record.respond_to?(attribute)
    attachment = record.public_send(attribute)
    return [] unless attachment.respond_to?(:attached?) && attachment.attached?

    if attachment.respond_to?(:attachments)
      attachment.attachments.map do |att|
        {
          url: helpers.url_for(att),
          filename: att.blob&.filename&.to_s
        }
      end
    else
      blob = attachment.try(:blob)
      [ { url: helpers.url_for(attachment), filename: blob&.filename&.to_s } ].compact
    end
  rescue
    []
  end

  def file_field_html_options
    options = {
      class: "file-upload__input",
      direct_upload: direct_upload?,
      data: {
        "file-upload-target": "input",
        action: file_input_actions
      }
    }

    options[:multiple] = true if multiple?
    options[:accept] = accept if accept.present?
    options[:"file-upload-max-count-value"] = max_count if multiple? && max_count.present?

    options
  end

  def dropzone_actions
    [
      "click->file-upload#open",
      "dragover->file-upload#dragOver",
      "dragleave->file-upload#dragLeave",
      "drop->file-upload#drop"
    ].join(" ")
  end

  private

  # https://guides.rubyonrails.org/active_storage_overview.html#direct-upload-javascript-events
  def file_input_actions
    [
      "change->file-upload#handleSelection",
      "direct-upload:initialize->file-upload#uploadInitialize",
      "direct-upload:start->file-upload#uploadStart",
      "direct-upload:progress->file-upload#uploadProgress",
      "direct-upload:error->file-upload#uploadError",
      "direct-upload:end->file-upload#uploadEnd"
    ].join(" ")
  end

  def normalize_color(value)
    symbolized = value.to_sym
    return symbolized if COLORS.include?(symbolized)

    raise ArgumentError, "color must be one of #{COLORS.join(', ')}, got #{value.inspect}"
  end
end
