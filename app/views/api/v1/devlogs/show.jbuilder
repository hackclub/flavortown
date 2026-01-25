json.extract! @devlog, :id, :body, :comments_count, :duration_seconds, :likes_count, :scrapbook_url, :created_at, :updated_at

json.comments @devlog.comments do |comment|
  json.extract! comment, :id, :body, :created_at, :updated_at

  json.author do
    json.extract! comment.user, :id, :display_name, :avatar
  end
end
