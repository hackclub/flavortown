json.total_votes @total_votes

json.recent_votes @recent_votes do |rv|
  json.project_id rv[:project_id]
  json.project_title rv[:project_title]
  json.vote_timestamp rv[:vote_timestamp]
  json.time_spent rv[:time_spent]
  json.ship_date rv[:ship_date]
  json.days_ago rv[:days_ago]
end
