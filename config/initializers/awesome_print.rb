require "awesome_print"

module InspectorHelper
  def awesome_inspect(record)
    AwesomePrint::Inspector.new(html: true).awesome(record)
  end
end

ActionView::Base.include InspectorHelper
