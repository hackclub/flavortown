class OneTime::MigrateChallengerEntriesJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    sidequest = Sidequest.find_or_create_by!(slug: "challenger") do |sq|
      sq.title = "Challenger Center"
      sq.description = "Build a space-themed project for the Challenger Center space challenge!"
    end

    projects = Project.where("description LIKE ?", "%Space Themed:%")

    created = 0
    skipped = 0

    projects.find_each do |project|
      entry = sidequest.sidequest_entries.find_or_create_by!(project: project)
      if entry.previously_new_record?
        created += 1
      else
        skipped += 1
      end
    end

    Rails.logger.info "[MigrateChallengerEntries] Complete. Created #{created} entries, skipped #{skipped} duplicates (#{projects.count} total space-themed projects found)."
  end
end
