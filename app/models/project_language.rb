class ProjectLanguage < ApplicationRecord
  belongs_to :project

  enum :status, { pending: 0, syncing: 1, synced: 2, failed: 3 }
end
