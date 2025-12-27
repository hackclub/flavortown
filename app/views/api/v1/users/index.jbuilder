json.users @users do |user|
    json.extract! user, :id, :slack_id, :display_name, :avatar

    json.project_ids user.projects.map(&:id)

    if user.leaderboard_optin?
      json.cookies user.cached_balance
    else
      json.cookies nil
    end
end

json.pagination do
    json.current_page @pagy.page
    json.total_pages @pagy.pages
    json.total_count @pagy.count
    json.next_page @pagy.next
end
