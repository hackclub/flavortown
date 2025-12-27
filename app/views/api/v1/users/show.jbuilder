json.extract! @user, :id, :slack_id, :display_name, :avatar

json.project_ids @user.projects.pluck(:id)
json.vote_count @user.votes.count
json.like_count @user.likes.count

json.devlog_seconds_total @user.devlog_seconds_total
json.devlog_seconds_today @user.devlog_seconds_today

if @user.leaderboard_optin?
    json.cookies @user.cached_balance
else
    json.cookies nil
end
