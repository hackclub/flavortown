module ApiDocsHelper
  def description_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return "" unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

      return "" unless controller_class&.respond_to?(:description)

    controller_class.description[action.to_sym] || ""
  end

  def query_url_params_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return {} unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

    return {} unless controller_class&.respond_to?(:url_params_model)

    controller_class.url_params_model[action.to_sym] || {}
  end

  def query_response_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return {} unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

    return {} unless controller_class&.respond_to?(:response_body_model)

    controller_class.response_body_model[action.to_sym] || {}
  end

  def query_request_body_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return {} unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

    return {} unless controller_class&.respond_to?(:request_body_model)

    controller_class.request_body_model[action.to_sym] || {}
  end
end
