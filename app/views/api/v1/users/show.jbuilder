json.extract! @user, :id, :slack_id, :display_name, :avatar

json.project_ids @user.projects.pluck(:id)

if @user.leaderboard_optin?
    json.cookies @user.cached_balance
else
    json.cookies nil
end
