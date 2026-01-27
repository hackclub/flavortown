require "awesome_print"

module InspectorHelper
  REDACTED_ATTRIBUTES = %w[
    address frozen_address frozen_address_ciphertext
    line_1 line_2 city state postal_code phone_number
  ].freeze

  def awesome_inspect(record)
    data = if record.is_a?(ActiveRecord::Base)
      record.attributes.transform_values.with_index do |value, _|
        key = record.attributes.keys[record.attributes.values.index(value)]
        if REDACTED_ATTRIBUTES.any? { |attr| key.to_s.include?(attr) }
          "[REDACTED]"
        else
          value
        end
      end.then { |vals| record.attributes.keys.zip(vals).to_h }
    else
      record
    end
    AwesomePrint::Inspector.new(html: true).awesome(data)
  end
end

ActionView::Base.include InspectorHelper
