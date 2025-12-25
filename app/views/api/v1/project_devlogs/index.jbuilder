json.devlogs @devlogs do |devlog|
  json.extract! devlog, :id, :body, :comments_count, :duration_seconds, :likes_count, :scrapbook_url, :created_at, :updated_at
end

json.pagination do
  json.current_page @pagy.page
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.next_page @pagy.next
end