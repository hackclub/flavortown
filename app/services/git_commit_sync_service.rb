class GitCommitSyncService
  EVENT_START_DATE = Time.parse("2025-12-15").freeze

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def sync!
    return { success: false, error: "No repo URL" } if project.repo_url.blank?

    provider = GitHost::Base.for(project.repo_url)
    return { success: false, error: "Unsupported git host" } unless provider

    last_sync = project.git_commit_posts.first&.created_at
    since = [ last_sync, EVENT_START_DATE ].compact.max
    commits = provider.fetch_commits(since: since)

    return { success: true, created: 0, skipped: 0 } if commits.empty?

    created = 0
    skipped = 0

    commits.each do |commit_data|
      if Post::GitCommit.exists?(sha: commit_data[:sha])
        skipped += 1
        next
      end

      git_commit = Post::GitCommit.create!(commit_data)
      Post.create!(
        project: project,
        user: nil,
        postable: git_commit
      )
      created += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to create git commit: #{e.message}")
      skipped += 1
    end

    project.update!(synced_at: Time.current)

    { success: true, created: created, skipped: skipped, provider: provider.provider_name }
  end

  def self.sync_all!
    Project.where.not(repo_url: nil).find_each do |project|
      new(project).sync!
    rescue => e
      Rails.logger.error("Failed to sync commits for project #{project.id}: #{e.message}")
    end
  end
end
