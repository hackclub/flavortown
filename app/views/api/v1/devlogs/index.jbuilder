json.devlogs @devlogs do |devlog|
  json.extract! devlog, :id, :body, :comments_count, :duration_seconds, :likes_count, :scrapbook_url, :created_at, :updated_at
end
