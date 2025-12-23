module ApiDocsHelper
  def query_url_params_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return {} unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

    return {} unless controller_class&.respond_to?(:url_params)

    controller_class.url_params[action.to_sym] || {}
  end

  def query_response_for(route)
    controller_name = route.defaults[:controller]
    action = route.defaults[:action]

    return {} unless controller_name && action

    controller_class =
      "#{controller_name.camelize}Controller".safe_constantize

    return {} unless controller_class&.respond_to?(:response)

    controller_class.response[action.to_sym] || {}
  end
end
