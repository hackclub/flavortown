json.extract! @devlog, :id, :body, :comments_count, :duration_seconds, :likes_count, :scrapbook_url, :created_at, :updated_at
json.media @devlog.attachments_attachments.includes(:blob).map { |attachment| { url: Rails.application.routes.url_helpers.rails_blob_path(attachment.blob, only_path: true), content_type: attachment.blob.content_type } }
