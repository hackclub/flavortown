json.extract! @user, :id, :slack_id, :display_name, :avatar

json.project_ids @user.projects.pluck(:id)
json.vote_count @user.votes.count
json.like_count @user.likes.count

json.devlog_seconds_total @user.devlog_seconds_total
json.devlog_seconds_today @user.devlog_seconds_today

if @user.leaderboard_optin?
    json.cookies @user.cached_balance

    json.balance_history @user.ledger_entries.order(created_at: :desc) do |entry|
        json.amount entry.amount
        json.source_type entry.source_type
        json.created_at entry.created_at
    end
else
    json.cookies nil
    json.balance_history nil
end

json.achievements @user.achievements do |earned_record|
  achievement = Achievement.slugged[earned_record.achievement_slug.to_sym]
  next unless achievement

  json.slug achievement.slug
  json.name achievement.display_name(earned: true)
  json.description achievement.display_description(earned: true)
end
