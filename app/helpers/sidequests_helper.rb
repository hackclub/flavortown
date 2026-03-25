module SidequestsHelper
  def render_sidequest_card(sidequest)
    partial = "sidequests/#{sidequest.slug}"
    partial = "sidequests/default" unless lookup_context.exists?(partial, [], true)
    render partial: partial, locals: { sidequest: sidequest }
  end
end
